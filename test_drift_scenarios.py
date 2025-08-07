#!/usr/bin/env python3
"""
Comprehensive drift testing scenarios for ML monitoring system
"""

import requests
import json
import time
import statistics

# Get API URL from terraform
import subprocess
result = subprocess.run(['terraform', 'output', '-raw', 'api_gateway_url'], 
                       cwd='infrastructure/terraform', 
                       capture_output=True, text=True)
API_URL = result.stdout.strip()

def send_request(features, description=""):
    """Send a single prediction request and return drift score"""
    data = {"features": features}
    response = requests.post(API_URL, json=data)
    result = response.json()
    
    drift_score = result.get('drift_score', 0)
    prediction = result.get('prediction', 0)
    
    alert = "🚨" if drift_score > 2.0 else "✅" if drift_score < 1.0 else "⚠️"
    print(f"{alert} {description}")
    print(f"   Features: {features}")
    print(f"   Prediction: ${prediction:,.0f}")
    print(f"   Drift Score: {drift_score:.3f}")
    print()
    
    return drift_score

def test_baseline_scenarios():
    """Test scenarios close to training baseline"""
    print("=" * 60)
    print("🔍 TESTING BASELINE SCENARIOS (Expected: Low Drift < 1.0)")
    print("=" * 60)
    
    baseline_tests = [
        {
            "features": {"bedrooms": 3, "bathrooms": 2, "sqft": 2000, "age": 25, "location_score": 5.5},
            "description": "Perfect baseline match"
        },
        {
            "features": {"bedrooms": 3, "bathrooms": 2, "sqft": 1950, "age": 20, "location_score": 6.0},
            "description": "Slight variation from baseline"
        },
        {
            "features": {"bedrooms": 4, "bathrooms": 2, "sqft": 2100, "age": 30, "location_score": 5.0},
            "description": "Normal variation within 1 std dev"
        }
    ]
    
    drift_scores = []
    for test in baseline_tests:
        score = send_request(test["features"], test["description"])
        drift_scores.append(score)
    
    avg_drift = statistics.mean(drift_scores)
    print(f"📊 Average baseline drift: {avg_drift:.3f} (Expected: < 1.0)")
    print()

def test_moderate_drift_scenarios():
    """Test scenarios with moderate drift"""
    print("=" * 60)
    print("⚠️  TESTING MODERATE DRIFT SCENARIOS (Expected: 1.0 < Drift < 2.0)")
    print("=" * 60)
    
    moderate_tests = [
        {
            "features": {"bedrooms": 6, "bathrooms": 4, "sqft": 3500, "age": 5, "location_score": 8.5},
            "description": "Upscale property (2-3 std devs from baseline)"
        },
        {
            "features": {"bedrooms": 1, "bathrooms": 1, "sqft": 1200, "age": 45, "location_score": 3.0},
            "description": "Modest property (2 std devs from baseline)"
        },
        {
            "features": {"bedrooms": 2, "bathrooms": 1, "sqft": 1000, "age": 50, "location_score": 2.5},
            "description": "Older, smaller property"
        }
    ]
    
    drift_scores = []
    for test in moderate_tests:
        score = send_request(test["features"], test["description"])
        drift_scores.append(score)
    
    avg_drift = statistics.mean(drift_scores)
    print(f"📊 Average moderate drift: {avg_drift:.3f} (Expected: 1.0-2.0)")
    print()

def test_high_drift_scenarios():
    """Test scenarios that should trigger drift alerts"""
    print("=" * 60)  
    print("🚨 TESTING HIGH DRIFT SCENARIOS (Expected: Drift > 2.0)")
    print("=" * 60)
    
    high_drift_tests = [
        {
            "features": {"bedrooms": 10, "bathrooms": 8, "sqft": 5000, "age": 0, "location_score": 10},
            "description": "Luxury mansion (4+ std devs from baseline)"
        },
        {
            "features": {"bedrooms": 1, "bathrooms": 1, "sqft": 400, "age": 80, "location_score": 1},
            "description": "Tiny old shack (4+ std devs from baseline)"
        },
        {
            "features": {"bedrooms": 8, "bathrooms": 1, "sqft": 6000, "age": 0, "location_score": 1},
            "description": "Weird configuration: huge but low quality"
        },
        {
            "features": {"bedrooms": 1, "bathrooms": 5, "sqft": 800, "age": 100, "location_score": 10},
            "description": "Another weird config: small but many bathrooms"
        }
    ]
    
    drift_scores = []
    alert_count = 0
    
    for test in high_drift_tests:
        score = send_request(test["features"], test["description"])
        drift_scores.append(score)
        if score > 2.0:
            alert_count += 1
    
    avg_drift = statistics.mean(drift_scores)
    print(f"📊 Average high drift: {avg_drift:.3f} (Expected: > 2.0)")
    print(f"🚨 Alerts triggered: {alert_count}/{len(high_drift_tests)}")
    print()

def test_individual_feature_drift():
    """Test drift by varying one feature at a time"""
    print("=" * 60)
    print("🔬 TESTING INDIVIDUAL FEATURE DRIFT")
    print("=" * 60)
    
    # Baseline for comparison
    baseline = {"bedrooms": 3, "bathrooms": 2, "sqft": 2000, "age": 25, "location_score": 5.5}
    
    # Test extreme values for each feature
    feature_tests = [
        {"feature": "bedrooms", "value": 15, "baseline": baseline},
        {"feature": "bathrooms", "value": 10, "baseline": baseline},
        {"feature": "sqft", "value": 8000, "baseline": baseline},
        {"feature": "age", "value": 150, "baseline": baseline},
        {"feature": "location_score", "value": 0.1, "baseline": baseline}
    ]
    
    for test in feature_tests:
        features = test["baseline"].copy()
        features[test["feature"]] = test["value"]
        
        description = f"Extreme {test['feature']}: {test['value']}"
        send_request(features, description)

def run_drift_simulation():
    """Run a comprehensive drift detection test"""
    print("🧪 COMPREHENSIVE DRIFT DETECTION TEST")
    print("Training baseline stats:")
    print("  Bedrooms: 3.04 ± 1.44")
    print("  Bathrooms: 1.99 ± 0.82")  
    print("  Sqft: 1998 ± 496")
    print("  Age: 24.7 ± 14.8")
    print("  Location: 5.53 ± 2.60")
    print("  Drift Alert Threshold: > 2.0")
    print()
    
    # Run all test scenarios
    test_baseline_scenarios()
    test_moderate_drift_scenarios() 
    test_high_drift_scenarios()
    test_individual_feature_drift()
    
    print("=" * 60)
    print("✅ DRIFT TESTING COMPLETE")
    print("=" * 60)
    print("📊 Check CloudWatch Dashboard for metrics visualization")
    print("📧 Check email/SNS for any drift alerts triggered")
    print("📝 Check Lambda logs for detailed drift calculations")
    print()
    print("🔗 CloudWatch Dashboard: Get URL from 'terraform output'")
    print("📋 Lambda Logs: /aws/lambda/mlops-drift-monitor-predictor")

if __name__ == "__main__":
    print(f"🎯 Testing drift detection at: {API_URL}")
    print()
    run_drift_simulation()