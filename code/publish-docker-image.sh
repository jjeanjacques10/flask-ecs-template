#!/bin/bash

# Replace YOUR_USERNAME with your Docker Hub username
DOCKER_USERNAME=YOUR_USERNAME

# Replace YOUR_IMAGE_NAME with the desired image name
IMAGE_NAME=flask-app-hello

# Build the Docker image
docker build --no-cache -t $DOCKER_USERNAME/$IMAGE_NAME .

# Login to Docker Hub
echo "$DOCKERHUB_PASSWORD" | docker login --username $DOCKER_USERNAME --password-stdin

# Push the Docker image to Docker Hub
docker push $DOCKER_USERNAME/$IMAGE_NAME
