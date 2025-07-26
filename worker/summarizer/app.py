from kafka import KafkaConsumer, KafkaProducer
from kafka.errors import KafkaError
import openai
import json
import os
from typing import Dict, Any
from dotenv import load_dotenv
load_dotenv()

openai_api_key = os.getenv("OPENAI_API_KEY")
if not openai_api_key:
    raise ValueError("Missing required environment variable: OPENAI_API_KEY")
client = openai.OpenAI(api_key=openai_api_key)

transcription_data_topic = "transcription.data"
summary_results_topic = "summary.results"

def get_kafka_config() -> Dict[str, Any]:
    try: 
        brokers = os.getenv("MSK_BROKERS", "")
        broker_list = [b for b in brokers.split(",") if b.strip()] or ["kafka:9092"]
        
        return {
            'bootstrap_servers': broker_list,  
            'security_protocol': 'PLAINTEXT',
        }
    except Exception as e:
        print(f"Error while parsing Kafka configuration: {e}")
        raise RuntimeError("Failed to get Kafka configuration") from e

def create_kafka_consumer(config: Dict[str, Any]) -> KafkaConsumer:  
    topic_name = transcription_data_topic
    consumer_config = {
        "bootstrap_servers": config["bootstrap_servers"],
        "auto_offset_reset": "latest",
        "group_id": "summary-group",
        "security_protocol": "PLAINTEXT"
    }

    try:
        return KafkaConsumer(topic_name, **consumer_config)
    except KafkaError as e:
        print(f"Failed to create Kafka consumer: {e}")
        raise RuntimeError(f"Kafka consumer initialization failed for topic '{topic_name}'") from e


def create_kafka_producer(config: Dict[str, Any]) -> KafkaProducer:
    producer_config = {
        "bootstrap_servers": config["bootstrap_servers"],
        "security_protocol": "PLAINTEXT"
    }

    try:
        return KafkaProducer(**producer_config)
    except KafkaError as e:
        print(f"Failed to create Kafka producer: {e}")
        raise RuntimeError("Kafka producer initialization failed") from e

def generate_clinic_note(patient_data):
    system_prompt = (
        "You are a medical scribe generating clinical notes for doctors. "
        "Given structured health data, output a professional SOAP note or consultation summary."
    )

    user_prompt = f"""
        Generate a clinic note from the following structured patient data:
        {patient_data}
    """
    try:
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
    
    except Exception as e:
        print(f"Error generating clinic note: {e}")
        raise RuntimeError("Failed to generate clinic note from patient data") from e


def main(event=None, context=None):
    try:
        # Get Kafka configuration
        kafka_config = get_kafka_config()
        
        # Create Kafka consumer and producer
        consumer = create_kafka_consumer(kafka_config)
        producer = create_kafka_producer(kafka_config)
    
        for message in consumer:
            try:
                data = json.loads(message.value.decode('utf-8'))
                session_id = data['sessionId']
                transcription_data = data['text']
                
                # Process clinic note
                summary = generate_clinic_note(transcription_data)
                
                # Send result back to Kafka
                producer.send(
                    summary_results_topic,
                    value=json.dumps({
                        'sessionId': session_id,
                        'text': summary,
                        'isFinal': True
                    }).encode('utf-8')
                )

                producer.flush()
            except Exception as e:
                print(f"Error processing message: {e}")

    except Exception as e:
        print(f"Error initializing Kafka client: {e}")
        raise

if __name__ == "__main__":
    main()