import json
import os
import sys

# Add error handling for imports
try:
    import numpy as np
    import pandas as pd
    import boto3
    from datetime import datetime
    print("✅ Basic imports successful")
except ImportError as e:
    print(f"❌ Import error: {e}")
    raise

try:
    import joblib
    print("✅ Joblib import successful")
except ImportError as e:
    print(f"❌ Joblib not available: {e}")
    raise

try:
    import sklearn
    from sklearn.ensemble import RandomForestRegressor
    from sklearn.preprocessing import StandardScaler
    print("✅ Scikit-learn imports successful")
except ImportError as e:
    print(f"❌ Scikit-learn not available: {e}")
    # Try alternative import paths
    try:
        import sklearn
        print(f"Sklearn version: {sklearn.__version__}")
        print(f"Sklearn path: {sklearn.__file__}")
    except:
        pass
    raise

# Global variables for model artifacts
model = None
scaler = None
training_stats = None
cloudwatch = None

def load_model_artifacts():
    """Load model artifacts with error handling"""
    global model, scaler, training_stats, cloudwatch
    
    try:
        print("Loading model artifacts...")
        model = joblib.load('model.pkl')
        scaler = joblib.load('scaler.pkl')
        training_stats = joblib.load('training_stats.pkl')
        cloudwatch = boto3.client('cloudwatch')
        print("✅ Model artifacts loaded successfully")
        return True
    except Exception as e:
        print(f"❌ Error loading model artifacts: {e}")
        return False

def lambda_handler(event, context):
    """Main Lambda handler with comprehensive error handling"""
    
    # Load model artifacts if not already loaded
    global model, scaler, training_stats, cloudwatch
    if model is None:
        if not load_model_artifacts():
            return {
                'statusCode': 500,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Failed to load model artifacts'})
            }
    
    try:
        # Log the incoming event for debugging
        print(f"Received event: {json.dumps(event)}")
        
        # Parse input - handle both direct invocation and API Gateway
        if 'body' in event:
            # API Gateway format
            if isinstance(event['body'], str):
                body = json.loads(event['body'])
            else:
                body = event['body']
        else:
            # Direct invocation format
            body = event
            
        print(f"Parsed body: {json.dumps(body)}")
        
        # Validate input
        if 'features' not in body:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Missing "features" in request body'})
            }
        
        features = body['features']
        print(f"Features: {features}")
        
        # Expected feature names
        expected_features = ['bedrooms', 'bathrooms', 'sqft', 'age', 'location_score']
        
        # Validate all required features are present
        missing_features = [f for f in expected_features if f not in features]
        if missing_features:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'error': f'Missing required features: {missing_features}',
                    'required_features': expected_features
                })
            }
        
        # Convert to DataFrame for prediction
        df = pd.DataFrame([features])
        df = df[expected_features]  # Ensure correct order
        print(f"DataFrame shape: {df.shape}")
        print(f"DataFrame: {df.to_dict()}")
        
        # Make prediction
        features_scaled = scaler.transform(df)
        prediction = model.predict(features_scaled)[0]
        print(f"Raw prediction: {prediction}")
        
        # Calculate drift score
        drift_score = detect_drift(features)
        print(f"Drift score: {drift_score}")
        
        # Log prediction for monitoring
        log_prediction(features, prediction)
        
        # Send metrics to CloudWatch (with error handling)
        try:
            send_cloudwatch_metrics(prediction, drift_score, features)
        except Exception as e:
            print(f"Warning: CloudWatch metrics failed: {e}")
        
        # Return successful response
        response = {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'prediction': float(prediction),
                'drift_score': float(drift_score),
                'timestamp': datetime.now().isoformat(),
                'features_received': features
            })
        }
        
        print(f"Returning response: {response}")
        return response
        
    except Exception as e:
        error_msg = f"Lambda execution error: {str(e)}"
        print(f"❌ {error_msg}")
        
        # Print full traceback for debugging
        import traceback
        print(f"Full traceback: {traceback.format_exc()}")
        
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'error': error_msg,
                'type': type(e).__name__
            })
        }

def log_prediction(features, prediction):
    """Log prediction data for later analysis"""
    try:
        log_data = {
            'timestamp': datetime.now().isoformat(),
            'features': features,
            'prediction': float(prediction)
        }
        print(f"PREDICTION_LOG: {json.dumps(log_data)}")
    except Exception as e:
        print(f"Error logging prediction: {e}")

def detect_drift(features):
    """Calculate drift score based on feature distribution"""
    try:
        drift_scores = []
        
        for feature, value in features.items():
            if feature in training_stats['feature_means']:
                # Z-score based drift detection
                mean = training_stats['feature_means'][feature]
                std = training_stats['feature_stds'][feature]
                if std > 0:
                    z_score = abs((value - mean) / std)
                    drift_scores.append(z_score)
        
        return float(np.mean(drift_scores)) if drift_scores else 0.0
    except Exception as e:
        print(f"Error calculating drift: {e}")
        return 0.0

def send_cloudwatch_metrics(prediction, drift_score, features):
    """Send metrics to CloudWatch"""
    try:
        # Prediction metrics
        cloudwatch.put_metric_data(
            Namespace='MLOps/HousePrices',
            MetricData=[
                {
                    'MetricName': 'Prediction',
                    'Value': float(prediction),
                    'Unit': 'Count'
                },
                {
                    'MetricName': 'DriftScore',
                    'Value': float(drift_score),
                    'Unit': 'None'
                }
            ]
        )
        
        # Feature metrics
        for feature, value in features.items():
            cloudwatch.put_metric_data(
                Namespace='MLOps/Features',
                MetricData=[
                    {
                        'MetricName': feature,
                        'Value': float(value),
                        'Unit': 'None'
                    }
                ]
            )
            
    except Exception as e:
        print(f"CloudWatch error: {e}")
        raise  # Re-raise to be caught by main handler