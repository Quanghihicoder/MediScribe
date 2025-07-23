from kafka import KafkaConsumer, KafkaProducer
import openai
import json
import os
import boto3
from typing import Dict, Any
# from dotenv import load_dotenv
# load_dotenv()

client = openai.OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

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
        "group_id": "summary-group",
        "security_protocol": config.get("security_protocol", "PLAINTEXT"),
    }
    
    if config.get("security_protocol") == "SASL_SSL":
        consumer_config.update({
            "sasl_mechanism": config.get("sasl_mechanism", "AWS_MSK_IAM"),
            "sasl_jaas_config": config.get("sasl_jaas_config"),
            "sasl_client_callback": config.get("sasl_client_callback"),
        })
    
    topic_name = f"{config.get('topic_prefix', '')}transcription.data"
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

def generate_clinic_note(patient_data):
    system_prompt = (
        "You are a medical scribe generating clinical notes for doctors. "
        "Given structured health data, output a professional SOAP note or consultation summary."
    )

    user_prompt = f"""
        Generate a clinic note from the following structured patient data:
        {patient_data}
    """

    response = client.chat.completions.create(
        model="gpt-4.1-nano",
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt}
        ],
        temperature=0.3,
        max_tokens=800,
    )

    return response.choices[0].message.content.strip()


def handler(event=None, context=None):
    try:
        # Get Kafka configuration with IAM auth
        kafka_config = get_kafka_config()
        
        # Create Kafka consumer and producer
        consumer = create_kafka_consumer(kafka_config)
        producer = create_kafka_producer(kafka_config)
        
        # Get topic names with optional prefix
        topic_prefix = kafka_config.get("topic_prefix", "")
        summary_results_topic = f"{topic_prefix}summary.results"
    
        for message in consumer:
            try:
                data = json.loads(message.value.decode('utf-8'))
                session_id = data['sessionId']
                transcription_data = data['text']
                
                # Process clinic note
                summary = generate_clinic_note(transcription_data)
                
                # Send result back to Kafka
                future = producer.send(
                    summary_results_topic,
                    value=json.dumps({
                        'sessionId': session_id,
                        'text': summary,
                        'isFinal': True
                    }).encode('utf-8')
                )

                future.add_callback(
                    lambda _: print(f"Message sent to {summary_results_topic}")
                ).add_errback(
                    lambda e: print(f"Failed to send message: {e}")
                )

                producer.flush()
                
            except Exception as e:
                print(f"Error processing message: {e}")

    except Exception as e:
        print(f"Error initializing Kafka client: {e}")
        raise

