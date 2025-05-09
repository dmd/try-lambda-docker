# Try-Lambda Framework

A simple framework for building and deploying an AWS Lambda application as a container image, driven by CloudFormation and triggered by S3 events. The core processing logic is factored out into an external executable (e.g., `logic.py`), making it reusable in any environment.

## Overview
- **Containerized Lambda**: Uses a Dockerfile based on the AWS Lambda Python 3.9 base image, installs dependencies (NumPy), and bundles the handler (`app.py`) along with a generic processor (`logic.py`).
- **Infrastructure as Code**: `cloudformation.yaml` defines the Lambda function, its execution role, and permission for S3 to invoke it.
- **S3 Event Wiring**: `build_and_deploy.sh` deploys the stack and configures S3 bucket notifications so that new objects under the input prefix automatically trigger the function.
- **Pluggable Logic**: The file-processing logic lives in a standalone script/executable (`logic.py` by default) that reads an input CSV, computes column sums, and writes an output CSV. You can replace it with any program that accepts `<in_path> <out_path>`. (Just make 
sure you install any necessary runtime dependnecies in the Dockerfile.)

## Prerequisites
- AWS CLI configured with permissions for ECR, Lambda, IAM, CloudFormation, and S3.
- Docker installed and running locally.

## Project Layout
```
app.py                  # Lambda handler: S3 download → external logic → S3 upload
logic.py                # Generic CSV processor (column sums)
Dockerfile              # Builds Lambda container image with NumPy
cloudformation.yaml     # Defines Lambda function and permissions via CloudFormation
build_and_deploy.sh     # Builds image, pushes to ECR, deploys CF stack, configures S3 notifications
destroy.sh              # Clears S3 notifications, deletes CF stack and ECR repo
example.csv             # Sample input CSV for local testing
```

## Deployment
1. Make scripts executable:
   ```bash
   chmod +x build_and_deploy.sh destroy.sh
   ```
2. Configure optional environment variables (defaults shown):
   ```bash
   export S3_BUCKET=3e.org              # MUST change! Existing bucket for triggers.
   export ECR_REPO_NAME=try-lambda      # MUST change! ECR repository name
   export AWS_REGION=us-east-1          # AWS region
   export IMAGE_TAG=latest              # Docker image tag
   export LAMBDA_FUNC_NAME=try-lambda-func
   export IN_PREFIX=try-lambda/in/      # S3 key prefix to watch
   export OUT_PREFIX=try-lambda/out/    # S3 key prefix for output
   export STACK_NAME=try-lambda-stack
   ```
3. Deploy:
   ```bash
   ./build_and_deploy.sh
   ```

The script will:
- Ensure (or create) the ECR repo
- Build & push the container image
- Deploy/update CloudFormation stack
- Configure S3 notifications for new objects under `$IN_PREFIX`

## Local Logic Testing
To test the processing logic locally without AWS:
```bash
# Process example.csv → out.csv
python logic.py example.csv out.csv
cat out.csv
```
You can swap out `logic.py` for any executable:
```bash
export LOGIC_CMD="./my_processor.sh"
``` 

## Teardown
To remove all deployed resources (except the S3 bucket itself):
```bash
./destroy.sh
``` 
This will:
- Clear the bucket’s notification configuration
- Delete the CloudFormation stack (Lambda + IAM role)
- Delete the ECR repository (force)

## Customization
- **Timeout/Memory**: Modify `Timeout` and `MemorySize` in `cloudformation.yaml` under `LambdaFunction`.
- **Prefixes**: Change `IN_PREFIX`/`OUT_PREFIX` in `app.py` or override via environment variables.
- **Logic**: Implement any processing logic in a script or binary that accepts two positional arguments: `<input_path> <output_path>`.

*This project provides a minimal, extensible pattern for containerized Lambda functions with pluggable logic and Infrastructure as Code.*

*Warning: No humans were involved in the writing of any of this code, or this readme file except for this line.*