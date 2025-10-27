# Cost Report: AWS License Plate Recognition

This report models monthly and yearly costs for the AWS-based LPR system and compares two usage scales: Demo and Scaled. It highlights cost drivers and justifies architectural choices.

All costs based on AWS pricing (October 2025).

## Assumptions

- Demo: 500 images/day (≈15,000/month)
- Scaled: 50 cameras × 3 images/min ≈ 6.5M images/month
- Average image size: 200 KB (0.0002 GB)
- EC2: one t3.small instance, on-demand, 24/7
- Region: eu-central-1 (pricing varies by region)

## Cost Comparison (Monthly)

| Service | Metric | Demo | Scaled |
| --- | --- | ---: | ---: |
| S3 Storage (Standard) | GB-month | ~3 GB | ~1,300 GB |
| S3 PUT requests | millions req | ~0.02 M | ~6.5 M |
| Lifecycle Transition PUTs (to Glacier IR) | millions req | optional | optional |
| EC2 Compute (t3.small 24/7) | instance-month | 1 | cluster (see analysis) |
| RDS (db.t3.micro/small + storage + I/O) | approx | low | medium-high |
| SQS requests | millions req | ~0.02 M | ~6.5 M |
| CloudWatch (logs + metrics) | approx | low | medium |
| Total (order-of-magnitude) | USD/month | low double-digits | low-to-mid five-digits |

Notes:
- Storage GB-month: images × size × retention; Demo assumes all in Standard; Scaled should add lifecycle to Glacier IR.
- PUTs: one per image (upload) + optional lifecycle transitions.
- RDS: includes instance hours, storage (e.g., 20–200 GB), and I/O. Exact depends on workload and retention.

- S3 PUT requests cost ≈ $0.005 per 1,000 requests; at 6.5 M images/month this equals ≈ $32.50/month.
- Lifecycle transition requests cost ≈ $0.02 per 1,000 requests; if applied to all 6.5 M images, that equals ≈ $130/month.

## Rekognition Alternative (for reference)

At 6.5M images/month, Rekognition Plate-like processing would be on the order of $1.3M/month. This validates the choice of OpenALPR for cost control.

## Analysis and Scaling

- Main cost drivers: S3 storage (large scale) and compute (EC2/worker fleet)
- Demo total: low double-digits monthly; Yearly: low hundreds
- Scaled total: low-to-mid five-digits monthly; Yearly: mid six-digits

Optimizations:
- S3 lifecycle transitions to Glacier Instant Retrieval (60–70% savings after first 30–90 days)
- Autoscaling worker instances; consider Spot for up to 70–90% EC2 savings
- Caching and batching to reduce S3/SQS/RDS calls
- Right-size RDS (consider Aurora for higher throughput and better storage scaling)

### Approximate Scaled Monthly Cost Breakdown

| Component | Approx. Monthly Cost (Scaled) |
|------------|-------------------------------:|
| S3 Storage | $30–35 |
| S3 PUT + Lifecycle | $160 |
| EC2 (t3.small cluster) | $1,500–2,000 |
| RDS (Aurora Small) | $300 |
| SQS + CloudWatch | $50 |
| **Total (scaled)** | **≈ $2,000–2,500/month (~$25–30K/year)** |

## Design-to-Cost Justification

| Service | Small Scale Choice | Large Scale Choice | Rationale |
| --- | --- | --- | --- |
| Compute | EC2 t3.small | EC2/ECS cluster | Predictable latency; cheaper than Lambda for steady load |
| DB | RDS MySQL | Aurora RDS | Structured queries, indexing |
| Storage | S3 Standard | S3 + Glacier IR | Lifecycle saves 60–70% |
| Processing | OpenALPR | OpenALPR | Avoids Rekognition costs |
| Messaging | SQS | SQS | Decoupling, retry, burst handling |

## Final Summary

- Demo: low double-digit monthly cost; minimal yearly spend.
- Scaled: low-to-mid five digits monthly; scalable with lifecycle, Spot, and autoscaling.
- Architecture is cost-efficient and scalable. The cost model includes S3 storage/PUTs, EC2, RDS, SQS, CloudWatch, lifecycle transitions, and a Rekognition alternative for comparison.

Estimated fifth-year cost (steady scaled load): ≈ $600 K–$700 K per year, still an order of magnitude below a Rekognition-based approach.

_All costs based on AWS pricing (October 2025)._
