# Use Python base image
FROM python:3.10-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy all files
COPY . .

# Install pip packages
RUN pip install --no-cache-dir \
    openai \
    python-dotenv \
    kafka-python 

# Run the script
CMD ["python", "-u", "app.py"]