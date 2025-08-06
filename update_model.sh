#!/bin/bash
# Quick script to update just the Lambda function with a new model

echo "🔄 Updating model deployment..."

# Retrain model
echo "🧠 Training new model..."
python src/model/train.py

# Create new deployment package
echo "📦 Creating new deployment package..."
rm -rf deployment model-api.zip
mkdir -p deployment
cp src/api/lambda_handler.py deployment/
cp model.pkl scaler.pkl training_stats.pkl deployment/

cd deployment
zip -r ../model-api.zip .
cd ..
rm -rf deployment

# Update just the S3 object and Lambda function
echo "☁️  Updating S3 and Lambda..."
cd infrastructure/terraform
terraform apply -target=aws_s3_object.lambda_zip -target=aws_lambda_function.model_api -auto-approve
cd ../..

echo "✅ Model updated successfully!"
