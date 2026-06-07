#!/bin/bash
set -e

echo "Starting LocalStack (AWS emulator)..."

# Check Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "ERROR: Docker is not running. Start Docker Desktop first."
  exit 1
fi

# Start LocalStack
docker run -d \
  --name localstack \
  -p 4566:4566 \
  -e SERVICES=ec2,s3,iam,vpc,sts \
  -e DEFAULT_REGION=us-east-1 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  localstack/localstack:latest

echo "Waiting for LocalStack to be ready..."
until curl -s http://localhost:4566/_localstack/health | grep -q '"ec2": "running"'; do
  sleep 2
done

echo "LocalStack is ready."
echo "AWS endpoint: http://localhost:4566"
echo ""
echo "Now run:"
echo "  cd environments/dev"
echo "  terraform init"
echo "  terraform plan"
