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
