#!/bin/bash
set -e


csurl(){ echo "https://${CODESPACE_NAME}-$1.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"; }

AWS_PAGER=""

awsonline="aws --endpoint-url=$(csurl 4566) --region=us-east-1"

echo "Deleting all Lambda functions..."
for fn in $($awsonline lambda list-functions --query 'Functions[].FunctionName' --output text); do
  echo "Deleting Lambda function: $fn"
  $awsonline lambda delete-function --function-name "$fn"
done

echo "Deleting all API Gateway APIs and routes..."
for api_id in $($awsonline apigateway get-rest-apis --query 'items[].id' --output text); do
  echo "Deleting API Gateway with ID: $api_id"
  $awsonline apigateway delete-rest-api --rest-api-id "$api_id"
done

echo "All Lambdas and API Gateways deleted."
