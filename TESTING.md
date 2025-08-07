# Drift Detection Testing Guide

Quick reference for testing your ML drift monitoring system.

## ⚡ Quick Test Commands

```bash
# Basic drift test (30 seconds)
python test_api.py

# Comprehensive drift analysis (2 minutes)  
python test_drift_scenarios.py

# Manual high-drift test
curl -X POST $API_URL -H "Content-Type: application/json" \
  -d '{"features": {"bedrooms": 10, "bathrooms": 8, "sqft": 5000, "age": 0, "location_score": 10}}'
```

## 📊 Understanding Results

**Drift Score Ranges:**
- `< 1.0` ✅ Normal (no action needed)
- `1.0-2.0` ⚠️ Moderate (monitor closely) 
- `> 2.0` 🚨 High drift (investigate!)

**Expected Test Results:**
```
🔍 Baseline: ~0.14 drift ✅
⚠️  Moderate: ~1.5 drift ⚠️  
🚨 High: ~3.2 drift, alerts triggered 🚨
```

## 🎯 Training Baseline

Your model was trained on:
- **Bedrooms:** 3.04 ± 1.44
- **Bathrooms:** 1.99 ± 0.82  
- **Sqft:** 1998 ± 496
- **Age:** 24.7 ± 14.8
- **Location:** 5.53 ± 2.60

## 🔧 Monitoring Commands

```bash
# Get API URL
terraform output api_gateway_url

# Check CloudWatch dashboard
terraform output cloudwatch_dashboard_url

# View Lambda logs
aws logs get-log-events \
  --log-group-name "/aws/lambda/mlops-drift-monitor-predictor" \
  --log-stream-name $(aws logs describe-log-streams \
    --log-group-name "/aws/lambda/mlops-drift-monitor-predictor" \
    --query 'logStreams[0].logStreamName' --output text)

# Check drift alarms
aws cloudwatch describe-alarms \
  --alarm-names "mlops-drift-monitor-high-drift"
```

## 🐛 Troubleshooting

**Drift always 0?**
- Check `training_stats.pkl` exists
- Verify feature names match exactly

**No alerts?**
- Try more extreme values: bedrooms=15, sqft=10000  
- Alarms need 2 consecutive periods > threshold
- Check SNS subscription confirmed

**API timeout?**
- Check Lambda logs for errors
- Verify container image deployed correctly

## 🧪 Advanced Testing

**Sustained high-drift for CloudWatch alarms:**
```bash
for i in {1..10}; do 
  curl -X POST $API_URL -H "Content-Type: application/json" \
    -d '{"features": {"bedrooms": 10, "bathrooms": 8, "sqft": 5000, "age": 0, "location_score": 10}}'
  sleep 30
done
```

**Load testing:**
```bash
# Generate 100 requests with random drift
python -c "
import requests, random, json
api_url = 'YOUR_API_URL'
for i in range(100):
    data = {'features': {
        'bedrooms': random.randint(1, 10),
        'bathrooms': random.randint(1, 8), 
        'sqft': random.randint(400, 5000),
        'age': random.randint(0, 100),
        'location_score': random.uniform(1, 10)
    }}
    r = requests.post(api_url, json=data)
    print(f'{i}: drift={r.json()[\"drift_score\"]:.2f}')
"
```

---

💡 **Tip:** Run tests after any model retraining to ensure drift detection still works correctly!