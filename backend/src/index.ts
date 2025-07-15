import express, { Request, Response } from 'express';
import http from 'http';
import path from 'path';
import morgan from 'morgan';
import bodyParser from 'body-parser';
import cors from 'cors';
import cookieParser from 'cookie-parser';
import dotenv from 'dotenv';
import { initKafka } from './producer/kafka';
import { setupWebSocket } from './websocket/server';
dotenv.config();

const environment = process.env.NODE_ENV || "development"
const port = process.env.PORT || 8000
const allowedOrigins = process.env.ALLOW_ORIGIN?.split(',') || [];

const app = express();
const __dirname = path.resolve();

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
app.use(morgan('dev'));
app.use(cookieParser());

const sendError = (req: Request, res: Response): void => {
  res.status(404);

  if (req.accepts('html')) {
    res.set('Content-Type', 'text/html');
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

  if (req.accepts('json')) {
    res.json({ status: 0, message: 'API not found!', data: [] });
    return;
  }

  res.type('txt').send('Not Found');
};

app.get('/', (req, res) => {
  res.status(200).send('OK');
});

app.use((req: Request, res: Response) => {
  sendError(req, res);
});

const server = http.createServer(app);
setupWebSocket(server);

(async () => {
  try {
    await initKafka();

    server.listen(port, () => {
      const url = environment === 'production' ? `:${port}` : `http://localhost:${port}`;
      console.log(`✅ Server is running on ${url}`);
    });
    
  } catch (err) {
    console.error('❌ Server start failed:', err);
    process.exit(1);
  }
})();