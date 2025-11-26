#!/bin/bash

# Monitoring Test Script
# This script helps you test the monitoring setup after deployment

set -e

echo "=== CP Assignment Monitoring Test Script ==="
echo ""

# Get Terraform outputs
echo "📊 Fetching infrastructure details..."
cd infra

ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")
TOKEN=$(terraform output -raw api_token 2>/dev/null || echo "")
GRAFANA_URL=$(terraform output -raw grafana_url 2>/dev/null || echo "http://$ALB_DNS/grafana")
PROMETHEUS_URL=$(terraform output -raw prometheus_url 2>/dev/null || echo "http://$ALB_DNS/prometheus")

cd ..

if [ -z "$ALB_DNS" ] || [ -z "$TOKEN" ]; then
    echo "❌ Error: Could not fetch Terraform outputs. Make sure infrastructure is deployed."
    exit 1
fi

echo "✅ ALB DNS: $ALB_DNS"
echo "✅ Grafana URL: $GRAFANA_URL"
echo "✅ Prometheus URL: $PROMETHEUS_URL"
echo ""

# Function to test endpoint
test_endpoint() {
    local url=$1
    local name=$2
    echo -n "Testing $name... "
    if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|302"; then
        echo "✅ OK"
        return 0
    else
        echo "❌ FAILED"
        return 1
    fi
}

# Test monitoring endpoints
echo "🔍 Testing Monitoring Endpoints"
echo "================================"
test_endpoint "$PROMETHEUS_URL/-/healthy" "Prometheus Health"
test_endpoint "$GRAFANA_URL/api/health" "Grafana Health"
test_endpoint "http://$ALB_DNS/" "Validator Service"
echo ""

# Test metrics endpoints
echo "📈 Testing Metrics Endpoints"
echo "============================"
echo "Note: These may fail if services aren't exposing metrics yet"
test_endpoint "http://$ALB_DNS:8000/metrics" "Validator Metrics" || echo "   (This is expected if metrics aren't implemented yet)"
echo ""

# Generate test traffic
echo "🚀 Generating Test Traffic"
echo "=========================="
read -p "Generate test traffic? This will send 100 valid and 20 invalid requests. (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Sending 100 valid requests..."
    for i in {1..100}; do
        curl -s -X POST "http://$ALB_DNS/" \
          -H "Content-Type: application/json" \
          -d "{\"token\": \"$TOKEN\", \"data\": {\"field1\": \"value$i\", \"field2\": \"test\", \"field3\": \"data\", \"field4\": \"value\"}}" \
          > /dev/null
        
        if [ $((i % 10)) -eq 0 ]; then
            echo "  Sent $i requests..."
        fi
    done
    echo "✅ Sent 100 valid requests"
    
    echo ""
    echo "Sending 20 invalid requests (wrong token)..."
    for i in {1..20}; do
        curl -s -X POST "http://$ALB_DNS/" \
          -H "Content-Type: application/json" \
          -d "{\"token\": \"invalid-token\", \"data\": {\"field1\": \"value$i\", \"field2\": \"test\", \"field3\": \"data\", \"field4\": \"value\"}}" \
          > /dev/null
    done
    echo "✅ Sent 20 invalid requests"
    
    echo ""
    echo "Sending 20 invalid requests (wrong payload)..."
    for i in {1..20}; do
        curl -s -X POST "http://$ALB_DNS/" \
          -H "Content-Type: application/json" \
          -d "{\"token\": \"$TOKEN\", \"data\": {\"field1\": \"value$i\", \"field2\": \"test\", \"field3\": \"data\"}}" \
          > /dev/null
    done
    echo "✅ Sent 20 invalid payload requests"
    
    echo ""
    echo "📊 Test traffic summary:"
    echo "  - Total requests: 140"
    echo "  - Valid requests: 100 (71.4%)"
    echo "  - Invalid token: 20 (14.3%)"
    echo "  - Invalid payload: 20 (14.3%)"
    echo "  - Expected error rate: ~28.6%"
fi

echo ""
echo "🎯 Next Steps"
echo "============="
echo "1. Open Grafana: $GRAFANA_URL"
echo "   - Get admin password: cd infra && terraform output -raw grafana_admin_password"
echo ""
echo "2. Open Prometheus: $PROMETHEUS_URL"
echo "   - Check targets: $PROMETHEUS_URL/targets"
echo "   - Check alerts: $PROMETHEUS_URL/alerts"
echo ""
echo "3. Verify metrics in Grafana dashboards:"
echo "   - Microservices Overview dashboard"
echo "   - CI/CD Pipeline dashboard"
echo "   - AWS Resources dashboard"
echo ""
echo "4. Check SQS queue for messages:"
echo "   aws s3 ls s3://\$(cd infra && terraform output -raw s3_bucket_name)/messages/ --recursive --profile CHECKPOINT"
echo ""
echo "✅ Monitoring test complete!"
