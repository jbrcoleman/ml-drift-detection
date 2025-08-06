import numpy as np
import pandas as pd
from scipy import stats
import joblib
import boto3
from datetime import datetime, timedelta

class DriftDetector:
    def __init__(self, training_stats):
        self.training_stats = training_stats
        self.drift_threshold = 2.0  # Z-score threshold
        
    def detect_feature_drift(self, current_features):
        """Detect drift in individual features"""
        drift_results = {}
        
        for feature, values in current_features.items():
            if feature in self.training_stats['feature_means']:
                # Statistical tests
                training_mean = self.training_stats['feature_means'][feature]
                training_std = self.training_stats['feature_stds'][feature]
                
                current_mean = np.mean(values)
                current_std = np.std(values)
                
                # Z-test for mean shift
                z_score = abs((current_mean - training_mean) / (training_std / np.sqrt(len(values))))
                
                # Kolmogorov-Smirnov test would go here for distribution comparison
                # (requires reference distribution data)
                
                drift_results[feature] = {
                    'mean_shift_z_score': z_score,
                    'is_drifted': z_score > self.drift_threshold,
                    'current_mean': current_mean,
                    'training_mean': training_mean,
                    'difference_percent': ((current_mean - training_mean) / training_mean) * 100
                }
        
        return drift_results
    
    def detect_prediction_drift(self, predictions):
        """Detect drift in model predictions"""
        pred_mean = np.mean(predictions)
        pred_std = np.std(predictions)
        
        training_mean = self.training_stats['target_mean']
        training_std = self.training_stats['target_std']
        
        z_score = abs((pred_mean - training_mean) / (training_std / np.sqrt(len(predictions))))
        
        return {
            'prediction_drift_z_score': z_score,
            'is_drifted': z_score > self.drift_threshold,
            'current_pred_mean': pred_mean,
            'training_target_mean': training_mean
        }

def analyze_cloudwatch_logs():
    """Analyze CloudWatch logs for drift detection"""
    logs_client = boto3.client('logs')
    
    # Query CloudWatch Logs for the last 24 hours
    end_time = datetime.now()
    start_time = end_time - timedelta(hours=24)
    
    try:
        response = logs_client.start_query(
            logGroupName='/aws/lambda/house-price-predictor',
            startTime=int(start_time.timestamp()),
            endTime=int(end_time.timestamp()),
            queryString='''
                fields @timestamp, @message
                | filter @message like /PREDICTION_LOG/
                | parse @message "PREDICTION_LOG: *" as log_data
            '''
        )
        
        # Process results (simplified - you'd want to poll for completion)
        # and extract prediction data for drift analysis
        
    except Exception as e:
        print(f"CloudWatch query error: {e}")

if __name__ == "__main__":
    # Example usage
    training_stats = joblib.load('training_stats.pkl')
    detector = DriftDetector(training_stats)
    
    # Simulate some current data
    current_features = {
        'bedrooms': [3, 4, 2, 5, 3],
        'bathrooms': [2, 3, 1, 3, 2],
        'sqft': [2100, 2800, 1500, 3200, 1900]
    }
    
    drift_results = detector.detect_feature_drift(current_features)
    print("Drift Detection Results:")
    for feature, result in drift_results.items():
        print(f"{feature}: {'DRIFT DETECTED' if result['is_drifted'] else 'OK'} "
              f"(Z-score: {result['mean_shift_z_score']:.2f})")