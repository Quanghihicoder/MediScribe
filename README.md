# 🧩 MediScribe – Speech to Clinical Notes

MediScribe is a full-stack web app that allows you to upload your speech and instantly generate clinical notes.

Give me a ⭐️ if you like this project.

# 🌐 Live Demo

- Feature Demo: https://www.youtube.com/watch?v=Jl4M3NOoPXI

# 🚀 TL;DR - How to Run Locally - A Single Container

## Pre-check

Free up these ports on your system: 2181 (Zookeeper), 9092 (Kafka), 8000 (Backend), 5173 (Frontend)

Make sure Docker is installed

## RUN

1. Run the setup script, and paste an openai key.

`./environment_setup.sh`

2. Start the whole stack

`docker-compose up --build`

- Wait for backend to finish booting (localhost:8000)
- Open http://localhost:5173 to start!

## TEST

Speech this passage (or put it into Google Translate and play the audio):

`Hi, my name's John. I'm 45 years old. I came in today because I've been having chest pain for the last couple of days. It gets worse when I’m doing things — like walking up stairs — but it doesn’t spread anywhere, it just stays in my chest.`

`Hi, I’m Lisa, I’m 38 years old. I came in today because I’ve been having this nagging pain in my lower abdomen for about a week now. It’s a dull ache that comes and goes, but it’s been getting more frequent. It’s worse when I’m sitting for a long time or right before my period. I haven’t had any nausea or fever, but it’s starting to worry me.`

# Keywords

ReactJS, TailwindCSS, NodeJS, Python, Kafka, Docker

# 🔁 System Flow

[Browser UI Mic audio] → [React Frontend Client] → Socket: audio:send

↓

[Node.js Backend] → Kafka Topic: audio.send

↓

[Transcriber (transcribes with Whisper)] → Kafka Topic: transcription.data

↓

[Summarizer (LLM, formats to SOAP note)] → Kafka Topic: summary.results

↓

[Node.js Backend] → Socket: summary:results

↓

[React Frontend Client]
