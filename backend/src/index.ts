import express, { Request, Response } from "express";
import http from "http";
import morgan from "morgan";
import cors from "cors";
import bodyParser from "body-parser";
import cookieParser from "cookie-parser";
import { Kafka } from "kafkajs";
import { Server } from "socket.io";
import dotenv from "dotenv";
dotenv.config();

const environment = process.env.NODE_ENV || "development";
const port = process.env.PORT || 8000;
const allowedOrigins = process.env.ALLOW_ORIGIN?.split(",") || [];

const app = express();

const corsOptions: cors.CorsOptions = {
  origin: (origin, callback) => {
    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(null, false);
    }
  },
  credentials: true,
};

app.use(cors(corsOptions));
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(morgan("dev"));
app.use(cookieParser());

const sendError = (req: Request, res: Response): void => {
  res.status(404);

  if (req.accepts("html")) {
    res.set("Content-Type", "text/html");
    res.send(`
      <!doctype html>
      <html lang="en">
      <head>
        <meta charset="utf-8">
        <title>Not Found</title>
        <meta name="description" content="Page not found">
      </head>
      <body>
        <p>Not Found! Please check your URL.</p>
      </body>
      </html>
    `);
    return;
  }

  if (req.accepts("json")) {
    res.json({ status: 0, message: "API not found!", data: [] });
    return;
  }

  res.type("txt").send("Not Found");
};

app.get("/", (req, res) => {
  res.status(200).send("OK");
});

app.use((req: Request, res: Response) => {
  sendError(req, res);
});

const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"],
  },
});

const kafka = new Kafka({
  clientId: "mediscribe",
  brokers: ["kafka:9092"],
});

const admin = kafka.admin();
const producer = kafka.producer();
const consumer = kafka.consumer({ groupId: "speech-to-summary-group" });

const audioSendTopic = "audio.send"
const transcriptionDataTopic = "transcription.data"
const transcriptionResultsTopic = "transcription.results"
const summaryResultsTopic = "summary.results"

async function waitForKafkaTopicReady(topic: string, timeoutMs = 30000) {
  await admin.connect();

  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try {
      const metadata = await admin.fetchTopicMetadata({ topics: [topic] });
      const topicMeta = metadata.topics.find(t => t.name === topic);

      if (topicMeta && topicMeta.partitions.length > 0) {
        const allHaveLeaders = topicMeta.partitions.every(p => p.leader !== -1);
        if (allHaveLeaders) {
          console.log(`✅ Kafka topic "${topic}" is fully ready.`);
          await admin.disconnect();
          return;
        }
      }
    } catch (err) {
      console.log(`⏳ Waiting for topic "${topic}" metadata to stabilize...`);
    }

    await new Promise(res => setTimeout(res, 2000));
  }

  await admin.disconnect();
  throw new Error(`❌ Kafka topic "${topic}" not ready after ${timeoutMs}ms`);
}

async function connectKafka() {
  await producer.connect();
  await consumer.connect();

  // Subscribe to multiple topics with one consumer
  await consumer.subscribe({ topic: transcriptionResultsTopic, fromBeginning: false });
  await consumer.subscribe({ topic: summaryResultsTopic, fromBeginning: false });

  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      if (!message.value) return;

      const result = JSON.parse(message.value.toString());

      if (topic === transcriptionResultsTopic) {
        io.to(result.sessionId).emit("transcription:received", {
          text: result.text,
          isFinal: result.isFinal,
        });
      } else if (topic === summaryResultsTopic) {
        io.to(result.sessionId).emit("summary:received", {
          text: result.text,
          isFinal: result.isFinal,
        });
      }
    },
  });
}

// Handle WebSocket connections
io.on("connection", (socket) => {
  console.log("Client connected:", socket.id);

  socket.on("audio:send", async (audioData) => {
    try {
      // Send audio chunk to Kafka for processing
      await producer.send({
        topic: audioSendTopic,
        messages: [
          {
            value: JSON.stringify({
              sessionId: socket.id,
              audio: audioData.toString("base64"),
              timestamp: new Date().toISOString(),
            }),
          },
        ],
      });
    } catch (error) {
      console.error("Error sending to Kafka:", error);
    }
  });

  socket.on("disconnect", () => {
    console.log("Client disconnected:", socket.id);
  });
});

(async () => {
  try {
    await waitForKafkaTopicReady(audioSendTopic)
    await waitForKafkaTopicReady(transcriptionDataTopic)
    await waitForKafkaTopicReady(transcriptionResultsTopic)
    await waitForKafkaTopicReady(summaryResultsTopic)

    await connectKafka().catch(console.error);
    
    server.listen(port, () => {
      const url =
        environment === "production" ? `:${port}` : `http://localhost:${port}`;
      console.log(`✅ Server is running on ${url}`);
    });
  } catch (err) {
    console.error("❌ Server start failed:", err);
    process.exit(1);
  }
})();
