from kafka import KafkaConsumer, KafkaProducer
import openai
import json
import os
from dotenv import load_dotenv
load_dotenv()

client = openai.OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

# Kafka configuration
bootstrap_servers = "kafka:9092"
transcription_data_topic = "transcription.data"
summary_results_topic = "summary.results"

consumer = KafkaConsumer(
    transcription_data_topic,
    bootstrap_servers=bootstrap_servers,
    auto_offset_reset='latest',
    group_id='summary-group'
)

producer = KafkaProducer(bootstrap_servers=bootstrap_servers)

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
    except Exception as e:
        print(f"Error processing message: {e}")
