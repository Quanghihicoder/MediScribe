from kafka import KafkaConsumer, KafkaProducer
import openai
import json
import os
from typing import Dict, Any
from dotenv import load_dotenv
load_dotenv()

client = openai.OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

def get_kafka_config() -> Dict[str, Any]:
    return {
        'bootstrap_servers': os.getenv("MSK_BROKERS").split(","),  
        'security_protocol': 'PLAINTEXT',
        'topic_prefix': os.getenv('TOPIC_PREFIX', '')
    }

def create_kafka_consumer(config: Dict[str, Any]) -> KafkaConsumer:  
    topic_name = f"{config.get('topic_prefix', '')}transcription.data"
    consumer_config = {
        "bootstrap_servers": config["bootstrap_servers"],
        "auto_offset_reset": "latest",
        "group_id": "summary-group",
        "security_protocol": "PLAINTEXT"
    }

    return KafkaConsumer(topic_name, **consumer_config)


def create_kafka_producer(config: Dict[str, Any]) -> KafkaProducer:
    producer_config = {
        "bootstrap_servers": config["bootstrap_servers"],
        "security_protocol": "PLAINTEXT"
    }
    
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

