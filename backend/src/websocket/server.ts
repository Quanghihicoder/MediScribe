import { WebSocketServer, WebSocket } from "ws";
import { Server } from "http";
import { sendToKafka } from "../producer/kafka";

export const setupWebSocket = (server: Server) => {
  const wss = new WebSocketServer({ server });

  wss.on("connection", (ws: WebSocket) => {
    console.log("🔌 WebSocket client connected");

    ws.on("message", async (message: Buffer) => {
      console.log("🎧 Audio chunk received:", message.length, "bytes");

      try {
        await sendToKafka(message)
      } catch (err) {
        console.error('❌ Kafka send error:', err);
      }
    });

    ws.on("close", () => {
      console.log("❌ WebSocket client disconnected");
    });
  });
}
