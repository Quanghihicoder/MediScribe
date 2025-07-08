#!/bin/bash

# Set up backend environment
cd backend
cp .env.template .env
cd ..

# Set up frontend environment
cd frontend
cp .env.template .env
cd ..
