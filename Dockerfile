FROM public.ecr.aws/lambda/python:3.9

# Install ML packages (compatible with Python 3.9)
RUN pip install --no-cache-dir \
    scikit-learn==1.6.1 \
    pandas==2.1.0 \
    numpy==1.26.0 \
    joblib==1.3.2 \
    scipy==1.11.0 \
    boto3==1.34.0

# Copy model files and Lambda handler
COPY model.pkl scaler.pkl training_stats.pkl ./
COPY src/api/lambda_handler.py ./

# Set the CMD to your handler
CMD ["lambda_handler.lambda_handler"]