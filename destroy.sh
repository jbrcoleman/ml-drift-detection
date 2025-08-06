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