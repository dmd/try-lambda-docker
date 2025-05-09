#!/usr/bin/env bash
set -euo pipefail

# Configuration
STACK_NAME="${STACK_NAME:-try-lambda-stack}"


echo "Deleting CloudFormation stack $STACK_NAME"
aws cloudformation delete-stack --stack-name "$STACK_NAME"
aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME"
echo "CloudFormation stack $STACK_NAME deleted."