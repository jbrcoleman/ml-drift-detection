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
rm -rf model-api.zip  # We don't need the zip anymore

# Create Dockerfile for Lambda container
cat > Dockerfile << 'EOF'
FROM public.ecr.aws/lambda/python:3.9

# Install ML packages
RUN pip install --no-cache-dir \
    scikit-learn==1.7.0 \
    pandas==2.1.0 \
    numpy==2.0.0 \
    joblib==1.3.2 \
    scipy==1.13.0 \
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
# First, ensure Terraform is properly initialized
cd infrastructure/terraform

# Clean up old state and reinitialize
rm -f .terraform.lock.hcl
terraform init

# Create the ECR repo
terraform apply -target=aws_ecr_repository.lambda_repo -auto-approve

# Get ECR repo URL
ECR_REPO_URL=$(terraform output -raw ecr_repository_url 2>/dev/null)
if [ -z "$ECR_REPO_URL" ]; then
    # Fallback if output doesn't exist yet
    ECR_REPO_URL="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/mlops-drift-monitor-lambda"
fi

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

cd infrastructure/terraform

# Deploy the rest of the infrastructure (Lambda function will use the image)
echo "🚀 Deploying Lambda function and infrastructure..."
terraform apply -auto-approve
cd ../..

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
