import whisper
import base64
import json
import os
import tempfile
import subprocess
import boto3
from kafka import KafkaConsumer, KafkaProducer
from typing import Dict, Any

# Load Whisper model (load once at module level)
model = whisper.load_model("small")  # or "base", "small", "medium", "large" based on your needs

def get_iam_auth_token() -> Dict[str, str]:
    """Generate IAM authentication token for MSK"""
    client = boto3.client('kafka')
    response = client.get_bootstrap_brokers(
        ClusterArn=os.getenv('MSK_CLUSTER_ARN')
    )
    return {
        'bootstrap_servers': response['BootstrapBrokerStringSaslIam'],
        'security_protocol': 'SASL_SSL',
        'sasl_mechanism': 'AWS_MSK_IAM',
        'sasl_jaas_config': 'software.amazon.msk.auth.iam.IAMLoginModule required;',
        'sasl_client_callback': 'software.amazon.msk.auth.iam.IAMClientCallbackHandler'
    }

def get_kafka_config() -> Dict[str, Any]:
    """Get Kafka configuration with IAM auth"""
    try:
        return get_iam_auth_token()
    except Exception as e:
        print(f"Error getting IAM auth token: {e}")
    

def create_kafka_consumer(config: Dict[str, Any]) -> KafkaConsumer:
    """Create and return a Kafka consumer with IAM auth"""
    consumer_config = {
        "bootstrap_servers": config["bootstrap_servers"],
        "auto_offset_reset": "latest",
        "group_id": "transcription-group",
        "security_protocol": config.get("security_protocol", "PLAINTEXT"),
    }
    
    if config.get("security_protocol") == "SASL_SSL":
        consumer_config.update({
            "sasl_mechanism": config.get("sasl_mechanism", "AWS_MSK_IAM"),
            "sasl_jaas_config": config.get("sasl_jaas_config"),
            "sasl_client_callback": config.get("sasl_client_callback"),
        })
    
    topic_name = f"{config.get('topic_prefix', '')}audio.send"
    return KafkaConsumer(topic_name, **consumer_config)

def create_kafka_producer(config: Dict[str, Any]) -> KafkaProducer:
    """Create and return a Kafka producer with IAM auth"""
    producer_config = {
        "bootstrap_servers": config["bootstrap_servers"],
        "security_protocol": config.get("security_protocol", "PLAINTEXT"),
    }
    
    if config.get("security_protocol") == "SASL_SSL":
        producer_config.update({
            "sasl_mechanism": config.get("sasl_mechanism", "AWS_MSK_IAM"),
            "sasl_jaas_config": config.get("sasl_jaas_config"),
            "sasl_client_callback": config.get("sasl_client_callback"),
        })
    
    return KafkaProducer(**producer_config)

def process_audio(audio_data):
    try:
        audio_bytes = base64.b64decode(audio_data)

        with tempfile.NamedTemporaryFile(suffix=".webm") as tmp_webm, tempfile.NamedTemporaryFile(suffix=".wav") as tmp_wav:
            # Write webm bytes and flush
            tmp_webm.write(audio_bytes)
            tmp_webm.flush()

            if os.path.getsize(tmp_webm.name) == 0:
                raise ValueError("Empty WEBM file generated")

            # Convert webm to wav using ffmpeg
            subprocess.run([
                "ffmpeg",
                "-y",  # overwrite output file if exists
                "-i", tmp_webm.name,
                "-ar", "16000",  # 16 kHz sample rate (recommended for Whisper)
                "-ac", "1",      # mono channel
                tmp_wav.name
            ], check=True)

            if os.path.getsize(tmp_wav.name) == 0:
                raise ValueError("Empty WAV file generated")
            
            result = model.transcribe(tmp_wav.name, language="en")
            return result["text"]
    except Exception as e:
        print(f"Error processing audio: {e}")
        return ""

def handler(event=None, context=None):
    try:
        # Get Kafka configuration with IAM auth
        kafka_config = get_kafka_config()
        
        # Create Kafka consumer and producer
        consumer = create_kafka_consumer(kafka_config)
        producer = create_kafka_producer(kafka_config)
        
        # Get topic names with optional prefix
        topic_prefix = kafka_config.get("topic_prefix", "")
        transcription_data_topic = f"{topic_prefix}transcription.data"
        transcription_results_topic = f"{topic_prefix}transcription.results"
        
        # Process messages
        for message in consumer:
            try:
                data = json.loads(message.value.decode('utf-8'))
                session_id = data['sessionId']
                audio_data = data['audio']
                
                # Process audio with Whisper
                transcription = process_audio(audio_data)
                
                # Send results
                future = producer.send(
                    transcription_results_topic,
                    value=json.dumps({
                        'sessionId': session_id,
                        'text': transcription,
                        'isFinal': True
                    }).encode('utf-8')
                )
                
                # Add callback for send result
                future.add_callback(
                    lambda _: print(f"Message sent to {transcription_results_topic}")
                ).add_errback(
                    lambda e: print(f"Failed to send message: {e}")
                )
                
                producer.send(
                    transcription_data_topic,
                    value=json.dumps({
                        'sessionId': session_id,
                        'text': transcription,
                        'isFinal': False
                    }).encode('utf-8')
                )
                
                producer.flush()
                
            except Exception as e:
                print(f"Error processing message: {e}")
                
    except Exception as e:
        print(f"Error initializing Kafka client: {e}")
        raise
