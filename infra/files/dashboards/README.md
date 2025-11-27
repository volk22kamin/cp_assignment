# Grafana Dashboards Setup Guide

## Current Monitoring Capabilities

Since your applications (validator and uploader services) don't expose `/metrics` endpoints yet, you can monitor:

✅ **Prometheus itself** - Health, performance, time series count
✅ **AWS Services** - Using pre-built community dashboards
✅ **Infrastructure** - Via CloudWatch metrics (if CloudWatch exporter is added)

## Quick Start: Import Pre-Built Dashboards

### 1. Prometheus Self-Monitoring

**Dashboard ID: 3662** - Prometheus 2.0 Stats

1. In Grafana, go to **Dashboards** → **Import**
2. Enter dashboard ID: `3662`
3. Click **Load**
4. Select your Prometheus datasource
5. Click **Import**

This shows:

- Prometheus uptime
- Scrape duration
- Time series count
- Memory usage
- Query performance

---

### 2. AWS CloudWatch Metrics (Optional - Requires CloudWatch Exporter)

To monitor AWS services (ECS, ALB, SQS, S3), you need to add CloudWatch Exporter to Prometheus.

**Dashboard IDs:**

- **7362** - AWS ECS Cluster Monitoring
- **11074** - AWS Application Load Balancer
- **584** - AWS SQS Monitoring

**To enable (future enhancement):**

1. Deploy CloudWatch Exporter as ECS service
2. Configure Prometheus to scrape it
3. Import these dashboards

---

### 3. Custom Dashboard for Your Services

I've created a basic dashboard at:
`infra/files/dashboards/infrastructure-overview.json`

**To import:**

1. In Grafana, go to **Dashboards** → **Import**
2. Click **Upload JSON file**
3. Select `infrastructure-overview.json`
4. Click **Import**

---

## What You Can Monitor Right Now

### Without Application Changes

**Prometheus Metrics:**

```promql
# Prometheus is running
up{job="prometheus"}

# Number of time series
prometheus_tsdb_head_series

# Memory usage
process_resident_memory_bytes{job="prometheus"}

# Scrape duration
prometheus_target_interval_length_seconds
```

**Manual Queries for AWS (if you add CloudWatch exporter):**

```promql
# SQS queue depth
aws_sqs_approximate_number_of_messages_visible_average

# ALB request count
aws_applicationelb_request_count_sum

# ECS CPU utilization
aws_ecs_cpuutilization_average
```

---

## Future: Application Metrics

When you add Prometheus client libraries to your apps, you'll be able to monitor:

**Validator Service:**

- Request rate
- Error rate
- Response time
- Token validation failures
- SQS publish duration

**Uploader Service:**

- Messages processed per second
- S3 upload success rate
- Queue depth
- Processing errors

---

## Recommended Dashboards to Import

1. **Prometheus 2.0 Stats** (ID: 3662) - Shows Prometheus health ✅
2. **Node Exporter Full** (ID: 1860) - If you add node exporter
3. **Docker and System Monitoring** (ID: 893) - Container metrics
4. **AWS ECS** (ID: 7362) - ECS cluster metrics (needs CloudWatch exporter)

---

## Next Steps

**For Demo/Assignment:**

1. ✅ Import Prometheus dashboard (ID: 3662)
2. ✅ Take screenshots showing monitoring works
3. ✅ Document in README that monitoring is set up

**For Production:**

1. Add CloudWatch Exporter for AWS metrics
2. Instrument applications with Prometheus client
3. Create custom dashboards for your specific use cases
4. Set up alerting rules

---

## Troubleshooting

**Q: Why don't I see my services in Prometheus targets?**
A: Your services don't expose `/metrics` endpoints yet. Prometheus only scrapes itself.

**Q: How do I monitor my ECS services without app changes?**
A: Use CloudWatch Exporter to pull ECS metrics into Prometheus, or use CloudWatch directly.

**Q: Can I monitor ALB without instrumenting apps?**
A: Yes! ALB publishes metrics to CloudWatch. Use CloudWatch Exporter or import ALB metrics.

**Q: What's the easiest way to show monitoring works?**
A: Import the Prometheus dashboard (ID: 3662) - it will show data immediately.
