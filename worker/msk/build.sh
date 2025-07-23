#!/bin/bash
set -e

echo "Building Lambda in Docker..."

# Clean up old builds
rm -rf ../../devops/modules/compute/lambda/build/msk_lambda.zip

# Run the Docker container to build
docker buildx build --platform linux/amd64 -f Dockerfile.lambda-build -t msk-lambda-builder --load .

# Create output folder
mkdir -p ../../devops/modules/compute/lambda/build/msk_lambda

# Copy build artifacts from container
CONTAINER_ID=$(docker create msk-lambda-builder)
docker cp $CONTAINER_ID:/var/task ../../devops/modules/compute/lambda/build/msk_lambda
docker rm $CONTAINER_ID

# Zip it
cd ../../devops/modules/compute/lambda/build/msk_lambda/task/
zip -r ../../msk_lambda.zip .

cd ../../
rm -rf ./msk_lambda

echo "Build complete: msk_lambda.zip"
