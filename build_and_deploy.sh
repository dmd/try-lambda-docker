#!/usr/bin/env bash
set -euo pipefail

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ECR_REPO_NAME="${ECR_REPO_NAME:-try-lambda}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
IMAGE_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:$IMAGE_TAG"
LAMBDA_FUNC_NAME="${LAMBDA_FUNC_NAME:-try-lambda-func}"
ROLE_NAME="${ROLE_NAME:-try-lambda-role}"
S3_BUCKET="${S3_BUCKET:-3e.org}"
IN_PREFIX="${IN_PREFIX:-try-lambda/in/}"
OUT_PREFIX="${OUT_PREFIX:-try-lambda/out/}"
TRUST_POLICY_FILE="trust-policy.json"
NOTIFICATION_FILE="notification.json"
PERMISSION_STATEMENT_ID="${LAMBDA_FUNC_NAME}-s3-trigger"

# Create S3 bucket if not exists
if ! aws s3api head-bucket --bucket "$S3_BUCKET" 2>/dev/null; then
    echo "Creating S3 bucket $S3_BUCKET in region $AWS_REGION"
    if [ "$AWS_REGION" = "us-east-1" ]; then
        aws s3api create-bucket --bucket "$S3_BUCKET"
    else
        aws s3api create-bucket --bucket "$S3_BUCKET" --create-bucket-configuration LocationConstraint="$AWS_REGION"
    fi
fi

# Create IAM role for Lambda if not exists
if ! aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
    cat > "$TRUST_POLICY_FILE" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
    aws iam create-role --role-name "$ROLE_NAME" --assume-role-policy-document file://"$TRUST_POLICY_FILE"
    rm "$TRUST_POLICY_FILE"
    aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
    aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
fi

# Create ECR repository if not exists
aws ecr describe-repositories --repository-names "$ECR_REPO_NAME" >/dev/null 2>&1 || \
    aws ecr create-repository --repository-name "$ECR_REPO_NAME"

# Build and push Docker image
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
# Login to AWS Public ECR for pulling the Lambda base image
echo "Logging into AWS Public ECR to pull base image"
aws ecr-public get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin public.ecr.aws
# Build the Docker image for x86_64 (linux/amd64) to match Lambda's architecture
docker build --platform linux/amd64 -t "$ECR_REPO_NAME" .
docker tag "$ECR_REPO_NAME:latest" "$IMAGE_URI"
docker push "$IMAGE_URI"

# Create or update Lambda function
ROLE_ARN="$(aws iam get-role --role-name "$ROLE_NAME" --query Role.Arn --output text)"
if aws lambda get-function --function-name "$LAMBDA_FUNC_NAME" >/dev/null 2>&1; then
    echo "Updating Lambda function code..."
    aws lambda update-function-code --function-name "$LAMBDA_FUNC_NAME" --image-uri "$IMAGE_URI"
else
    echo "Creating Lambda function..."
    aws lambda create-function \
        --function-name "$LAMBDA_FUNC_NAME" \
        --package-type Image \
        --code ImageUri="$IMAGE_URI" \
        --role "$ROLE_ARN" \
        --timeout 60 \
        --memory-size 128
fi

# Wait for the Lambda function to become active before configuring triggers
echo "Waiting for Lambda function to become Active..."
aws lambda wait function-active --function-name "$LAMBDA_FUNC_NAME"

# Add permission for S3 to invoke Lambda
aws lambda add-permission \
    --function-name "$LAMBDA_FUNC_NAME" \
    --statement-id "$PERMISSION_STATEMENT_ID" \
    --action "lambda:InvokeFunction" \
    --principal s3.amazonaws.com \
    --source-arn "arn:aws:s3:::$S3_BUCKET" \
    --source-account "$AWS_ACCOUNT_ID" 2>/dev/null || true

# Configure S3 bucket notification
FUNCTION_ARN="$(aws lambda get-function --function-name "$LAMBDA_FUNC_NAME" --query Configuration.FunctionArn --output text)"
cat > "$NOTIFICATION_FILE" <<EOF
{
  "LambdaFunctionConfigurations": [
    {
      "Id": "$PERMISSION_STATEMENT_ID",
      "LambdaFunctionArn": "$FUNCTION_ARN",
      "Events": ["s3:ObjectCreated:*"] ,
      "Filter": {
        "Key": {
          "FilterRules": [
            {"Name": "prefix", "Value": "$IN_PREFIX"},
            {"Name": "suffix", "Value": ".csv"}
          ]
        }
      }
    }
  ]
}
EOF
aws s3api put-bucket-notification-configuration --bucket "$S3_BUCKET" --notification-configuration file://"$NOTIFICATION_FILE"
rm "$NOTIFICATION_FILE"

echo "Deployment complete. Lambda function ARN: $FUNCTION_ARN"