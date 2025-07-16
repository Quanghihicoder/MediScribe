#!/bin/bash

# Set up backend environment
cd backend
cp .env.template .env
cd ..

# Set up frontend environment
cd frontend
cp .env.template .env
cd ..


# Set up summarizer environment
read -p "Enter your openai token: " TOKEN
cd worker/summarizer
echo "OPENAI_API_KEY='$TOKEN'" >> .env
cd ../../



echo ".env files copied successfully."