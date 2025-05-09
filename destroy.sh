#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
ECR_REPO_NAME="${ECR_REPO_NAME:-try-lambda}"
STACK_NAME="${STACK_NAME:-try-lambda-stack}"
S3_BUCKET="${S3_BUCKET:-3e.org}"


echo "Clearing S3 bucket notifications on bucket $S3_BUCKET"
aws s3api put-bucket-notification-configuration \
  --bucket "$S3_BUCKET" \
  --notification-configuration '{}'
echo "S3 bucket notifications cleared."
  
echo "Deleting CloudFormation stack $STACK_NAME"
aws cloudformation delete-stack --stack-name "$STACK_NAME"
aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME"
echo "CloudFormation stack $STACK_NAME deleted."
  
echo "Deleting ECR repository $ECR_REPO_NAME"
if aws ecr describe-repositories --region "$AWS_REGION" --repository-names "$ECR_REPO_NAME" >/dev/null 2>&1; then
  aws ecr delete-repository --region "$AWS_REGION" --repository-name "$ECR_REPO_NAME" --force
  echo "ECR repository $ECR_REPO_NAME deleted."
else
  echo "ECR repository $ECR_REPO_NAME not found, skipping."
fi