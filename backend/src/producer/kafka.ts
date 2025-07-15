import { Kafka } from 'kafkajs';

// Kafka Producer Setup
const kafka = new Kafka({
  clientId: 'audio-app',
  brokers: [process.env.KAFKA_BROKER || 'kafka:9092'],
});

const producer = kafka.producer();

export const initKafka = async () => {
  try {
    await producer.connect();
    console.log("🟢 Kafka producer connected");
  } catch (err) {
    console.error("Kafka connection error:", err);
  }
};

export const sendToKafka = async (buffer: Buffer | ArrayBuffer | Uint8Array | number[] | string) => {

  let kafkaBuffer;

  if (buffer instanceof Buffer) { 
    kafkaBuffer = buffer;
  } else if (buffer instanceof ArrayBuffer) {
    kafkaBuffer = Buffer.from(new Uint8Array(buffer));
  } else if (Array.isArray(buffer)) {
    kafkaBuffer = Buffer.from(buffer);
  } else {
    kafkaBuffer = Buffer.from(buffer);
  }
  
  await producer.send({
    topic: "speech.audio.raw",
    messages: [{ value: kafkaBuffer }],
  });
};



