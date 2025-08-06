#!/bin/bash
# deploy-terraform.sh

set -e  # Exit on any error

echo "🚀 MLOps Drift Monitor - Terraform Deployment"
echo "=============================================="

# Check prerequisites
echo "🔍 Checking prerequisites..."

# Check if AWS CLI is configured
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "❌ AWS CLI not configured. Run 'aws configure' first."
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform not installed. Installing via apt..."
    sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
    sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
    sudo apt-get update && sudo apt-get install terraform
fi

# Check if Python dependencies are installed
if ! python -c "import sklearn, pandas, numpy, boto3, joblib, scipy" >/dev/null 2>&1; then
    echo "📦 Installing Python dependencies..."
    pip install -r requirements.txt
fi

# Train the model
echo "🧠 Training the model..."
if [ ! -f "model.pkl" ] || [ ! -f "scaler.pkl" ] || [ ! -f "training_stats.pkl" ]; then
    python src/model/train.py
    echo "✅ Model training completed"
else
    echo "✅ Model files already exist"
fi

# Verify model files exist
if [ ! -f "model.pkl" ] || [ ! -f "scaler.pkl" ] || [ ! -f "training_stats.pkl" ]; then
    echo "❌ Model files not found. Training may have failed."
    exit 1
fi

# Verify model files exist
if [ ! -f "model.pkl" ] || [ ! -f "scaler.pkl" ] || [ ! -f "training_stats.pkl" ]; then
    echo "❌ Model files not found. Training may have failed."
    exit 1
fi

echo "📋 Model files ready:"
ls -la *.pkl

# Create Docker image for Lambda
echo "🐳 Creating Lambda container image..."
sudo rm -rf model-api.zip  # We don't need the zip anymore

# Create Dockerfile for Lambda container
cat > Dockerfile << 'EOF'
FROM public.ecr.aws/lambda/python:3.9

# Install ML packages
RUN pip install --no-cache-dir \
    scikit-learn==1.3.2 \
    pandas==2.1.0 \
    numpy==1.25.0 \
    joblib==1.3.2 \
    scipy==1.11.0 \
    boto3==1.34.0

# Copy model files and Lambda handler
COPY model.pkl scaler.pkl training_stats.pkl ./
COPY src/api/lambda_handler.py ./

# Set the CMD to your handler
CMD ["lambda_handler.lambda_handler"]
EOF

echo "🔧 Building Docker image..."
docker build -t mlops-lambda .

# Get AWS account info for ECR
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=${AWS_REGION:-us-east-1}

echo "☁️  Setting up ECR repository..."
# First, ensure Terraform creates the ECR repo
cd infrastructure/terraform
terraform apply -target=aws_ecr_repository.lambda_repo -auto-approve
ECR_REPO_URL=$(terraform output -raw ecr_repository_url 2>/dev/null || echo "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/mlops-drift-monitor-lambda")
cd ../..

echo "🔐 Logging into ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REPO_URL

echo "🏷️  Tagging and pushing image..."
docker tag mlops-lambda:latest $ECR_REPO_URL:latest
docker push $ECR_REPO_URL:latest

echo "✅ Container image pushed to ECR: $ECR_REPO_URL:latest"

# Clean up local files
rm -f Dockerfile

echo "🚀 Container ready for Lambda deployment"

# Setup Terraform configuration
echo "⚙️  Setting up Terraform configuration..."

# Copy terraform.tfvars if it doesn't exist
if [ ! -f "infrastructure/terraform/terraform.tfvars" ]; then
    cp infrastructure/terraform/terraform.tfvars.example infrastructure/terraform/terraform.tfvars
    echo "📝 Created terraform.tfvars from example. Please edit it with your settings."
    echo "   Especially set your email address for alerts!"
    echo ""
    echo "   Edit: infrastructure/terraform/terraform.tfvars"
    echo "   Then run this script again."
    exit 0
fi

# Verify the zip file exists before proceeding
if [ ! -f "model-api.zip" ]; then
    echo "❌ model-api.zip not found. This is required for Terraform."
    exit 1
fi

cd infrastructure/terraform

echo "🔧 Initializing Terraform..."
terraform init

echo "📋 Planning deployment..."
terraform plan -out=tfplan

echo "🚀 Applying infrastructure..."
terraform apply tfplan

echo ""
echo "✅ Deployment completed successfully!"
echo ""

# Get outputs
API_URL=$(terraform output -raw api_gateway_url)
DASHBOARD_URL=$(terraform output -raw cloudwatch_dashboard_url)
LAMBDA_NAME=$(terraform output -raw lambda_function_name)
ECR_REPO=$(terraform output -raw ecr_repository_url)

echo "📊 Your MLOps monitoring system is ready!"
echo "========================================"
echo ""
echo "🔗 API Endpoint:"
echo "   $API_URL"
echo ""
echo "📈 CloudWatch Dashboard:"
echo "   $DASHBOARD_URL"
echo ""
echo "🐳 Container Image:"
echo "   $ECR_REPO:latest"
echo ""
echo "🧪 Test your API:"
echo "   curl -X POST $API_URL \\"
echo "     -H \"Content-Type: application/json\" \\"
echo "     -d '{\"features\": {\"bedrooms\": 3, \"bathrooms\": 2, \"sqft\": 2000, \"age\": 10, \"location_score\": 7}}'"
echo ""
echo "📱 Next steps:"
echo "   1. Test the API endpoint above"
echo "   2. Check the CloudWatch dashboard"
echo "   3. Run the drift simulation scripts"
echo "   4. Set up your email alerts (check your inbox for SNS confirmation)"
echo ""

cd ../..

# Create test scripts
echo "📝 Creating test scripts..."

cat > test_api.py << 'EOF'
#!/usr/bin/env python3
"""Test script for the deployed ML API"""

import requests
import json
import random
import time

# Get the API URL from Terraform output
import subprocess
result = subprocess.run(['terraform', 'output', '-raw', 'api_gateway_url'], 
                       cwd='infrastructure/terraform', 
                       capture_output=True, text=True)
API_URL = result.stdout.strip()

def test_normal_prediction():
    """Test with normal data"""
    data = {
        "features": {
            "bedrooms": 3,
            "bathrooms": 2,
            "sqft": 2000,
            "age": 10,
            "location_score": 7
        }
    }
    
    response = requests.post(API_URL, json=data)
    print(f"Normal prediction: {response.json()}")
    return response.json()

def generate_traffic(num_requests=10):
    """Generate some normal traffic"""
    print(f"Sending {num_requests} normal requests...")
    
    for i in range(num_requests):
        data = {
            "features": {
                "bedrooms": random.randint(2, 4),
                "bathrooms": random.randint(1, 3),
                "sqft": random.randint(1500, 3000),
                "age": random.randint(0, 30),
                "location_score": random.uniform(4, 9)
            }
        }
        
        response = requests.post(API_URL, json=data)
        result = response.json()
        print(f"Request {i+1}: Prediction=${result.get('prediction', 0):.0f}, Drift={result.get('drift_score', 0):.2f}")
        
        time.sleep(1)  # Be nice to the API

def simulate_drift(num_requests=10):
    """Simulate data drift"""
    print(f"Simulating drift with {num_requests} requests...")
    
    for i in range(num_requests):
        # Drift toward smaller, older, worse-located homes
        data = {
            "features": {
                "bedrooms": random.randint(1, 2),  # Smaller homes
                "bathrooms": 1,                    # Fewer bathrooms
                "sqft": random.randint(800, 1200), # Much smaller
                "age": random.randint(40, 60),     # Older homes
                "location_score": random.uniform(1, 4)  # Worse locations
            }
        }
        
        response = requests.post(API_URL, json=data)
        result = response.json()
        print(f"Drift {i+1}: Prediction=${result.get('prediction', 0):.0f}, Drift={result.get('drift_score', 0):.2f} {'🚨' if result.get('drift_score', 0) > 2 else ''}")
        
        time.sleep(1)

if __name__ == "__main__":
    print(f"Testing API at: {API_URL}")
    print()
    
    # Test single prediction
    test_normal_prediction()
    print()
    
    # Generate normal traffic
    generate_traffic(5)
    print()
    
    # Simulate drift
    simulate_drift(5)
    print()
    
    print("✅ Testing complete! Check your CloudWatch dashboard for metrics.")
EOF

chmod +x test_api.py

cat > update_model.sh << 'EOF'
#!/bin/bash
# Quick script to update just the Lambda container with a new model

echo "🔄 Updating model container..."

# Retrain model
echo "🧠 Training new model..."
python src/model/train.py

# Get AWS info
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=${AWS_REGION:-us-east-1}
ECR_REPO="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/mlops-drift-monitor-lambda"

# Create new Dockerfile
cat > Dockerfile << 'DOCKER_EOF'
FROM public.ecr.aws/lambda/python:3.9

RUN pip install --no-cache-dir \
    scikit-learn==1.3.2 \
    pandas==2.1.0 \
    numpy==1.25.0 \
    joblib==1.3.2 \
    scipy==1.11.0 \
    boto3==1.34.0

COPY model.pkl scaler.pkl training_stats.pkl ./
COPY src/api/lambda_handler.py ./

CMD ["lambda_handler.lambda_handler"]
DOCKER_EOF

# Build and push
echo "🐳 Building and pushing updated container..."
docker build -t mlops-lambda .
docker tag mlops-lambda:latest $ECR_REPO:latest

aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REPO
docker push $ECR_REPO:latest

# Update Lambda function
echo "⚡ Updating Lambda function..."
aws lambda update-function-code \
    --function-name mlops-drift-monitor-predictor \
    --image-uri $ECR_REPO:latest

# Clean up
rm -f Dockerfile

echo "✅ Model container updated successfully!"
EOF

chmod +x update_model.sh
#!/bin/bash
# Quick script to update just the Lambda function with a new model

echo "🔄 Updating model deployment..."

# Retrain model
echo "🧠 Training new model..."
python src/model/train.py

# Create new deployment package
echo "📦 Creating new deployment package..."
sudo rm -rf deployment model-api.zip
mkdir -p deployment
cp src/api/lambda_handler.py deployment/
cp model.pkl scaler.pkl training_stats.pkl deployment/

cd deployment
zip -r ../model-api.zip .
cd ..
sudo rm -rf deployment

# Update just the S3 object and Lambda function
echo "☁️  Updating S3 and Lambda..."
cd infrastructure/terraform
terraform apply -target=aws_s3_object.lambda_zip -target=aws_lambda_function.model_api -auto-approve
cd ../..

echo "✅ Model updated successfully!"
EOF

chmod +x update_model.sh
#!/bin/bash
# Clean up all AWS resources

echo "🗑️  Destroying MLOps monitoring infrastructure..."
cd infrastructure/terraform
terraform destroy -auto-approve
cd ../..
echo "✅ All resources destroyed"
EOF

chmod +x destroy.sh

echo ""
echo "🎉 Setup complete! Use these commands:"
echo "   ./test_api.py          - Test your deployed API"
echo "   ./update_model.sh      - Retrain and deploy new model version"
echo "   ./destroy.sh           - Clean up AWS resources when done"