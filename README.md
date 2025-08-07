# MLOps Drift Monitor

A production-ready ML monitoring system that detects data drift and model performance degradation in real-time. Built with AWS Lambda, CloudWatch, and automated alerting.

![Architecture](https://img.shields.io/badge/AWS-Lambda%20%7C%20CloudWatch%20%7C%20API%20Gateway-orange)
![Python](https://img.shields.io/badge/Python-3.9-blue)
![ML](https://img.shields.io/badge/ML-scikit--learn-green)

## What This Does

- **Deploys a production ML model** (house price predictor) to AWS Lambda using container images
- **Monitors incoming data** for distribution shifts and anomalies in real-time
- **Detects drift** using statistical Z-score analysis comparing to training baselines
- **Sends alerts** when drift scores exceed configurable thresholds
- **Provides dashboards** for visualization and monitoring via CloudWatch
- **Tracks metrics** including predictions, drift scores, and feature distributions

Perfect for learning production MLOps practices and understanding how models behave in production environments.

## Architecture

```
┌─────────────┐    ┌──────────────┐    ┌─────────────────┐
│   Client    │───▶│ API Gateway  │───▶│ Lambda Function │
│  Request    │    │              │    │   (Container)   │
└─────────────┘    └──────────────┘    └─────────────────┘
                                                │
                   ┌─────────────────────────────┼─────────────────────────────┐
                   │                             ▼                             │
                   │                    ┌─────────────────┐                    │
                   │                    │ Model Prediction│                    │
                   │                    │  + Drift Check  │                    │
                   │                    └─────────────────┘                    │
                   │                             │                             │
                   ▼                             ▼                             ▼
            ┌─────────────┐            ┌─────────────────┐         ┌─────────────────┐
            │ CloudWatch  │            │   CloudWatch    │         │   CloudWatch    │
            │    Logs     │            │    Metrics      │         │    Alarms       │
            └─────────────┘            └─────────────────┘         └─────────────────┘
                                               │                             │
                                               ▼                             ▼
                                     ┌─────────────────┐         ┌─────────────────┐
                                     │   Dashboard     │         │   SNS Alerts    │
                                     │  Visualization  │         │   (Email/Slack) │
                                     └─────────────────┘         └─────────────────┘
```

## Quick Start

### Prerequisites
- **AWS Account** with CLI configured (`aws configure`)
- **Docker** installed and running
- **Python 3.9+** 
- **Terraform** (auto-installed by deploy script if needed)

### 1. Clone and Deploy
```bash
git clone <your-repo-url>
cd ml-drift-detection

# Deploy everything (model training, infrastructure, container build)
./deploy.sh
```

The deployment script will:
- Train the baseline model with synthetic house price data
- Build and push a Lambda container image to ECR
- Deploy infrastructure via Terraform (API Gateway, Lambda, CloudWatch, SNS)
- Configure monitoring dashboards and alerts

### 2. Test the Deployment
```bash
# Test with normal house price prediction
curl -X POST https://YOUR_API_URL/predict \
  -H "Content-Type: application/json" \
  -d '{
    "features": {
      "bedrooms": 3,
      "bathrooms": 2,
      "sqft": 2000,
      "age": 10,
      "location_score": 7
    }
  }'

# Expected response:
# {
#   "prediction": 684159.80,
#   "drift_score": 0.32,
#   "timestamp": "2025-08-07T16:45:44.771465",
#   "features_received": {...}
# }
```

### 3. Test Drift Detection
```bash
# Quick test with basic drift scenarios
python test_api.py

# Comprehensive drift testing with detailed analysis
python test_drift_scenarios.py
```

Both scripts will automatically test your deployed API and show real-time drift detection results.

## Monitoring Features

### Real-time Drift Detection
- **Feature-level monitoring**: Each input feature (bedrooms, bathrooms, sqft, age, location_score) is monitored
- **Z-score analysis**: Compares incoming data distributions to training baselines
- **Configurable thresholds**: Default drift alert at Z-score > 2.0
- **Immediate feedback**: Drift scores returned with every prediction

### CloudWatch Integration
- **Custom metrics**: Prediction values, drift scores, feature distributions
- **Visual dashboards**: Real-time graphs showing trends and anomalies  
- **Automated alarms**: Trigger when drift exceeds thresholds or Lambda errors occur
- **Log analysis**: Detailed prediction logs for debugging and analysis

### Alert System
- **SNS notifications**: Email/Slack alerts when drift is detected
- **Multiple thresholds**: High drift (>2.0), Lambda errors (>5), low request volume
- **Configurable endpoints**: Set your email in `terraform.tfvars`

## Project Structure

```
ml-drift-detection/
├── src/
│   ├── model/
│   │   ├── train.py                    # Model training with synthetic data
│   │   └── drift_detector.py           # Drift detection algorithms  
│   └── api/
│       └── lambda_handler.py           # Lambda function with drift monitoring
├── infrastructure/
│   └── terraform/
│       ├── main.tf                     # Lambda, API Gateway, CloudWatch resources
│       ├── variables.tf                # Configuration variables
│       ├── outputs.tf                  # API URLs and resource ARNs
│       └── terraform.tfvars            # Environment-specific settings
├── test_api.py                         # Quick drift testing script
├── test_drift_scenarios.py             # Comprehensive drift testing suite
├── deploy.sh                           # Complete deployment automation
├── update_model.sh                     # Model retraining and redeployment  
├── destroy.sh                          # Clean up all AWS resources
├── requirements.txt                    # Python dependencies
├── .gitignore                          # Git ignore file for sensitive/generated files
├── TESTING.md                          # Quick testing reference guide
└── README.md                           # This documentation
```

## Configuration

### Environment Settings
Edit `infrastructure/terraform/terraform.tfvars`:
```hcl
aws_region         = "us-east-1"
project_name       = "mlops-drift-monitor" 
drift_threshold    = "2.0"          # Z-score threshold for alerts
alert_email        = "your-email@domain.com"  # SNS alert destination
log_retention_days = 14             # CloudWatch log retention
```

### Model Parameters
Edit `src/model/train.py` to modify:
- **Training data generation**: Feature ranges, correlations, sample size
- **Model architecture**: Currently RandomForestRegressor with 100 estimators
- **Feature engineering**: Add/remove features, transformations
- **Drift sensitivity**: Adjust statistical thresholds

## Operational Workflows

### Normal Operations
```bash
# Check system health
aws lambda get-function --function-name mlops-drift-monitor-predictor

# View recent predictions and drift scores
aws logs get-log-events --log-group-name "/aws/lambda/mlops-drift-monitor-predictor"

# Monitor via CloudWatch Dashboard
# URL provided in deployment output
```

### Model Updates
```bash
# Retrain model and redeploy
./update_model.sh

# This will:
# 1. Retrain with latest data
# 2. Build new container image  
# 3. Update Lambda function
# 4. Maintain zero downtime
```

### Drift Response
When drift is detected:
1. **Investigate**: Check CloudWatch logs for specific feature drift
2. **Analyze**: Compare current vs. training data distributions  
3. **Decide**: Retrain model, adjust thresholds, or investigate data sources
4. **Action**: Use `update_model.sh` for retraining or adjust `terraform.tfvars` for thresholds

### Cleanup
```bash
# Remove all AWS resources
./destroy.sh
```

## Testing Drift Detection

The system includes comprehensive testing capabilities to verify drift detection is working correctly.

### Understanding Drift Scores

**Training Baseline Statistics:**
- Bedrooms: 3.04 ± 1.44
- Bathrooms: 1.99 ± 0.82  
- Sqft: 1998 ± 496
- Age: 24.7 ± 14.8 years
- Location Score: 5.53 ± 2.60

**Drift Score Interpretation:**
- **< 1.0**: Normal variation, no concerns ✅
- **1.0-2.0**: Moderate drift, monitor closely ⚠️
- **> 2.0**: High drift, investigation needed 🚨

### Test Scripts

**Quick Testing:**
```bash
python test_api.py
# Tests: baseline → normal traffic → moderate drift
# Runtime: ~30 seconds
```

**Comprehensive Testing:**
```bash
python test_drift_scenarios.py
# Tests: baseline → moderate → high drift → individual features
# Runtime: ~2 minutes
# Provides detailed analysis of each scenario
```

### Manual Testing Examples

**Low Drift (Normal Data):**
```bash
curl -X POST $API_URL -H "Content-Type: application/json" \
  -d '{"features": {"bedrooms": 3, "bathrooms": 2, "sqft": 2000, "age": 25, "location_score": 5.5}}'
# Expected: drift_score < 1.0
```

**High Drift (Luxury Property):**
```bash
curl -X POST $API_URL -H "Content-Type: application/json" \
  -d '{"features": {"bedrooms": 10, "bathrooms": 8, "sqft": 5000, "age": 0, "location_score": 10}}'
# Expected: drift_score > 2.0, triggers alert 🚨
```

**High Drift (Low-End Property):**
```bash
curl -X POST $API_URL -H "Content-Type: application/json" \
  -d '{"features": {"bedrooms": 1, "bathrooms": 1, "sqft": 400, "age": 80, "location_score": 1}}'
# Expected: drift_score > 2.0, triggers alert 🚨
```

### Expected Test Results

The comprehensive test should show:

```
🔍 BASELINE SCENARIOS: Average drift ~0.14 ✅
⚠️  MODERATE DRIFT: Average drift ~1.5 ⚠️
🚨 HIGH DRIFT: Average drift ~3.2, 4/4 alerts triggered 🚨
🔬 INDIVIDUAL FEATURES: Shows which features contribute most to drift
```

### Monitoring Test Results

**Real-time Monitoring:**
- Drift scores returned immediately with each prediction
- Watch for 🚨 alerts when drift > 2.0

**CloudWatch Dashboard:**
```bash
# Get dashboard URL
terraform output cloudwatch_dashboard_url
```
- View prediction trends and drift score graphs
- Monitor feature distribution changes over time

**Lambda Logs:**
```bash
aws logs get-log-events \
  --log-group-name "/aws/lambda/mlops-drift-monitor-predictor" \
  --log-stream-name $(aws logs describe-log-streams \
    --log-group-name "/aws/lambda/mlops-drift-monitor-predictor" \
    --query 'logStreams[0].logStreamName' --output text)
```

**CloudWatch Alarms:**
```bash
# Check if drift alarms are triggered
aws cloudwatch describe-alarms \
  --alarm-names "mlops-drift-monitor-high-drift"
```

### Troubleshooting Tests

**If drift scores are always 0:**
- Check that `training_stats.pkl` contains baseline statistics
- Verify feature names match exactly (case-sensitive)
- Ensure model was retrained after any feature changes

**If no high drift detected:**
- Use more extreme values (e.g., bedrooms: 15, sqft: 10000)
- Check training baseline statistics are loaded correctly
- Verify Z-score calculation in Lambda logs

**If CloudWatch alarms don't trigger:**
- Alarms need 2 consecutive 5-minute periods above threshold
- Run sustained high-drift traffic: `for i in {1..10}; do curl [high-drift-request]; sleep 30; done`
- Check SNS topic subscription is confirmed

### Continuous Testing

**Automated Testing:**
Add to your CI/CD pipeline:
```bash
# In your deployment pipeline
./deploy.sh
python test_drift_scenarios.py
# Fail deployment if drift detection not working
```

**Production Monitoring:**
- Set up scheduled CloudWatch synthetic tests
- Monitor drift score distributions in production
- Alert on absence of drift (could indicate data pipeline issues)

## Advanced Features

### Drift Detection Methods
- **Z-score analysis**: Statistical comparison to training distribution means/stds
- **Feature-wise monitoring**: Individual drift scores for each input feature
- **Aggregated scoring**: Mean drift score across all features
- **Extensible design**: Easy to add Population Stability Index (PSI), KS tests

### Production Monitoring  
- **Prediction logging**: All predictions logged with timestamp and features
- **Performance tracking**: Lambda duration, memory usage, error rates
- **Cost monitoring**: CloudWatch metrics for AWS billing optimization
- **Scalability**: Handles production traffic loads via Lambda auto-scaling

### Alerting Options
- **Email notifications**: Via SNS topic subscription
- **Slack integration**: Configure SNS to Slack webhook
- **PagerDuty**: For critical production alerts
- **Custom webhooks**: Extend SNS to any endpoint

## Troubleshooting

### Common Issues

**API timeouts:**
- Check Lambda logs: `aws logs get-log-events --log-group-name "/aws/lambda/mlops-drift-monitor-predictor"`
- Verify container image compatibility
- Increase Lambda timeout in `terraform.tfvars`

**Drift scores always zero:**
- Ensure model was trained with same feature names
- Check `training_stats.pkl` contains baseline statistics
- Verify feature names match exactly (case-sensitive)

**No alerts received:**
- Confirm SNS topic subscription in AWS console
- Check spam folder for SNS confirmation email
- Verify `alert_email` in `terraform.tfvars`

### Performance Optimization
- **Cold starts**: Container images have ~10-20s cold start
- **Memory tuning**: Adjust `memory_size` in Terraform for performance/cost balance
- **Batch processing**: Consider SQS for high-volume scenarios

## Learning Outcomes

After working through this project, you'll understand:
- **Container-based Lambda deployment** with ECR and Terraform
- **Real-time ML monitoring** patterns and drift detection techniques  
- **Infrastructure as Code** for reproducible ML deployments
- **CloudWatch integration** for comprehensive system observability
- **Production ML operations** including updates, rollbacks, and incident response

## Extension Ideas

- **A/B testing**: Deploy multiple model versions and compare performance
- **Feature store integration**: Connect to centralized feature management
- **Model explainability**: Add SHAP values for prediction interpretability  
- **Advanced drift detection**: Implement Population Stability Index, adversarial validation
- **Multi-model serving**: Extend to support multiple models with routing
- **Stream processing**: Integrate with Kinesis for real-time data pipelines

---

**Deployment Status:** ✅ Ready for production use
**API Endpoint:** Check deployment output for your specific URL
**Monitoring:** CloudWatch Dashboard and SNS alerts configured
**Last Updated:** 2025-08-07