#!/usr/bin/env bash
set -euo pipefail

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ECR_REPO_NAME="${ECR_REPO_NAME:-try-lambda}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
IMAGE_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:$IMAGE_TAG"
LAMBDA_FUNC_NAME="${LAMBDA_FUNC_NAME:-try-lambda-func}"
S3_BUCKET="${S3_BUCKET:-3e.org}"
IN_PREFIX="${IN_PREFIX:-try-lambda/in/}"
STACK_NAME="${STACK_NAME:-try-lambda-stack}"
TEMPLATE_FILE="${TEMPLATE_FILE:-cloudformation.yaml}"


# Ensure ECR repository exists and push image
aws ecr describe-repositories --repository-names "$ECR_REPO_NAME" >/dev/null 2>&1 || \
  aws ecr create-repository --repository-name "$ECR_REPO_NAME"

aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
aws ecr-public get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin public.ecr.aws

docker build --platform linux/amd64 -t "$ECR_REPO_NAME" .
docker tag "$ECR_REPO_NAME:latest" "$IMAGE_URI"
docker push "$IMAGE_URI"

# Deploy CloudFormation stack
aws cloudformation deploy \
  --stack-name "$STACK_NAME" \
  --template-file "$TEMPLATE_FILE" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
      ImageUri="$IMAGE_URI" \
      LambdaFunctionName="$LAMBDA_FUNC_NAME" \
      BucketName="$S3_BUCKET"

# Retrieve Lambda function ARN from CloudFormation outputs
FUNCTION_ARN="$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query "Stacks[0].Outputs[?OutputKey=='FunctionArn'].OutputValue" \
  --output text)"

echo "Deployment complete. Lambda ARN: $FUNCTION_ARN"
  
# Configure S3 bucket notification for new objects under IN_PREFIX
NOTIFICATION_FILE="notification.json"
echo "Configuring S3 bucket notification on bucket $S3_BUCKET (prefix: $IN_PREFIX)"
cat > "$NOTIFICATION_FILE" <<EOF
{
  "LambdaFunctionConfigurations": [
    {
      "Id": "${LAMBDA_FUNC_NAME}-s3-trigger",
      "LambdaFunctionArn": "$FUNCTION_ARN",
      "Events": ["s3:ObjectCreated:*"] ,
      "Filter": {
        "Key": {
          "FilterRules": [
            {"Name": "prefix", "Value": "$IN_PREFIX"}
          ]
        }
      }
    }
  ]
}
EOF
aws s3api put-bucket-notification-configuration \
  --bucket "$S3_BUCKET" \
  --notification-configuration file://"$NOTIFICATION_FILE"
rm "$NOTIFICATION_FILE"
echo "S3 bucket notification configured."