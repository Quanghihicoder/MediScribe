#!/bin/bash
set -e

echo "Building Lambda in Docker..."

# Clean up old builds
rm -rf ../../devops/modules/compute/lambda/build/summarizer_lambda.zip

# Run the Docker container to build
docker buildx build --platform linux/amd64 -f Dockerfile.lambda-build -t summarizer-lambda-builder --load .

# Create output folder
mkdir -p ../../devops/modules/compute/lambda/build/summarizer_lambda

# Copy build artifacts from container
CONTAINER_ID=$(docker create summarizer-lambda-builder)
docker cp $CONTAINER_ID:/var/task ../../devops/modules/compute/lambda/build/summarizer_lambda
docker rm $CONTAINER_ID

# Zip it
cd ../../devops/modules/compute/lambda/build/summarizer_lambda/task/
zip -r ../../summarizer_lambda.zip .

cd ../../
rm -rf ./summarizer_lambda

echo "Build complete: summarizer_lambda.zip"
