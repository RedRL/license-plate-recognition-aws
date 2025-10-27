# License Plate Recognition on AWS

## Quick Deploy

Run these commands from the deployment directory (`deployment/`).

- Windows (PowerShell):

```powershell
  cd deployment
  ./deploy-aws.ps1
```

- macOS/Linux or Windows (Git Bash):

```bash
  cd deployment
  bash deploy-aws.sh
  ```

Prerequisites:
- AWS CLI configured for your target account/region (`aws configure`).
- The script provisions infrastructure, deploys the app, and prints the Web Application URL when done.

A production-style, cloud-deployed License Plate Recognition (LPR) system built on AWS. Users upload vehicle images via an Angular frontend; a Flask API stores images in S3 and enqueues work to SQS; an EC2 worker runs OpenALPR to detect plate number and color; results are persisted to MySQL (RDS) and queried back by the frontend. One command deploys all infrastructure and application components.

## System Architecture

High-level flow:

- Frontend (Angular) → REST API (Flask on EC2) → S3 (image storage) → SQS (async work) → EC2 Worker (OpenALPR) → RDS MySQL (results)

Diagram-style description:

- Upload: Browser uploads → API → S3 object created → API pushes SQS message with S3 key
- Process: EC2 Worker consumes SQS → downloads from S3 → runs OpenALPR → writes plate/color to RDS
- Query: Frontend queries API → API reads from RDS and returns results

## Components

- S3 (Images)
  - Stores uploaded images; versioning enabled; CORS configured
  - Optional event notifications for future trigger-based flows
- SQS (+ DLQ)
  - Decouples ingestion from processing; absorbs traffic bursts; retries and DLQ for poison messages
- EC2 (t3.small)
  - Hosts Flask backend API and the worker (OpenALPR toolchain)
  - Nginx fronts Angular static site and proxies API
- RDS (MySQL)
  - Relational storage for detection records with indexes on time/plate/color/make/model
- IAM + CloudWatch
  - Least-privilege roles for EC2 to access S3/SQS; logs and metrics via CloudWatch
- Angular Frontend
  - Upload images, query detections, and edit DB entries

## Detection Capabilities

**Currently Implemented:**
- License plate number recognition (via OpenALPR)
- Vehicle color detection

**Not Implemented:**
- Vehicle make/model detection - no reliable free tools available; architecture supports future integration when a cost-effective solution becomes available

## Design Decisions & Trade-offs

- EC2 vs Lambda
  - EC2 provides predictable performance for CPU-bound OpenALPR and avoids cold starts; cheaper for steady workloads
- RDS vs DynamoDB
  - Structured schema and relational filters (e.g., multi-field and time-based queries) fit RDS; DynamoDB less suitable for ad-hoc relational queries at scale
- OpenALPR vs Rekognition
  - Local, free OpenALPR avoids very high per-image API costs of Rekognition
- S3 → SQS vs synchronous
  - Asynchronous pipeline decouples upload from compute; prevents API timeouts and handles bursts gracefully
- S3 Lifecycle
  - For scale, transition older images to Glacier Instant Retrieval to reduce storage cost

## Security & Key Management

- PEM keys removed from git and history; generated locally and git-ignored
- Instance access via SSH key pair; for production, prefer SSM Session Manager
- Principle of least privilege across IAM roles and policies

## Deployment

- Single command creates all infrastructure and deploys the app:
  - macOS/Linux/Git Bash: `bash deployment/deploy-aws.sh`
  - Windows PowerShell: `powershell -File deployment/deploy-aws.ps1`
- The script provisions CloudFormation (VPC, EC2, RDS, S3, SQS+DLQ, IAM), configures Nginx, initializes DB schema, and prints the Web Application URL at the end

## Frontend Usage

- Upload a vehicle image; the UI shows processing status and result when available
- Query detections with filters; results display timestamp, plate number, and attributes
- Edit or update existing DB entries for demo purposes

### Demo-Only Behavior: Query DB Suggestions

- The "Query DB" panel builds autocomplete suggestions by scanning the whole table for convenience. This is intentionally for demo only and would be inefficient and unsafe in production. In production, index-backed, parameterized queries with pagination should be used.

## Future Improvements

- Add Make/Model module when a reliable, cost-effective model is available
- Add S3 lifecycle rules from Standard → Glacier Instant Retrieval
- Introduce autoscaling or ECS workers; consider GPU-class instances for higher accuracy models

## License / Credits

- OpenALPR (community) for local plate detection
- AWS free-tier friendly design where possible; t3.small used for predictable compute
