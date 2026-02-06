#!/bin/bash
set -e

# ----------------------------
# Variables
# ----------------------------
LAMBDA_NAME="ec2_control"
API_NAME="ec2-api"
REGION="us-east-1"

export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
AWS_PAGER=""

# ----------------------------
# Zip Lambda
# ----------------------------
echo "Zipping Lambda..."
cd lambda
zip -r ../lambda.zip .
cd ..

csurl(){ echo "https://${CODESPACE_NAME}-$1.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"; }

AWS_PAGER=""
AWS_LOCAL="aws --endpoint-url=http://localhost:4566 --region=us-east-1"

awsonline="aws --endpoint-url=$(csurl 4566) --region=us-east-1"

# ----------------------------
# Create or update Lambda
# ----------------------------
if $awsonline lambda get-function --function-name "$LAMBDA_NAME" >/dev/null 2>&1; then
    echo "Lambda exists, updating code..."
    AWS_PAGER="" $awsonline lambda update-function-code \
        --function-name "$LAMBDA_NAME" \
        --zip-file fileb://lambda.zip
else
    echo "Creating Lambda function..."
    AWS_PAGER="" $awsonline lambda create-function \
        --function-name "$LAMBDA_NAME" \
        --runtime python3.9 \
        --role arn:aws:iam::000000000000:role/lambda-role \
        --handler ec2_control.lambda_handler \
        --zip-file fileb://lambda.zip
fi

# ----------------------------
# Create or reuse API Gateway
# ----------------------------
API_ID=$($awsonline apigateway get-rest-apis --query "items[?name=='$API_NAME'] | sort_by(@, &createdDate)[-1].id" --output text)
if [ "$API_ID" == "None" ] || [ -z "$API_ID" ]; then
    echo "Creating API Gateway..."
    API_ID=$($awsonline apigateway create-rest-api --name "$API_NAME" --query 'id' --output text)
else
    echo "API Gateway already exists: $API_ID"
fi

ROOT_ID=$($awsonline apigateway get-resources --rest-api-id $API_ID --query 'items[?path==`/`].id' --output text)

# ----------------------------
# Create /start /stop /status routes if not exist
# ----------------------------
for path in start stop status; do
  RES_ID=$($awsonline apigateway get-resources --rest-api-id $API_ID --query "items[?path=='/$path'].id | [0]" --output text)
  if [ "$RES_ID" == "None" ] || [ -z "$RES_ID" ]; then
      echo "Creating route /$path..."
      RES_ID=$($awsonline apigateway create-resource --rest-api-id $API_ID --parent-id $ROOT_ID --path-part $path --query 'id' --output text)
      AWS_PAGER="" $awsonline apigateway put-method --rest-api-id $API_ID --resource-id $RES_ID --http-method POST --authorization-type NONE
      AWS_PAGER="" $awsonline apigateway put-integration \
        --rest-api-id $API_ID \
        --resource-id $RES_ID \
        --http-method POST \
        --type AWS_PROXY \
        --integration-http-method POST \
        --uri arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/arn:aws:lambda:$REGION:000000000000:function:$LAMBDA_NAME/invocations
  else
      echo "Route /$path already exists."
  fi
done

# ----------------------------
# Deploy API
# ----------------------------
echo "Deploying API..."
$awsonline apigateway create-deployment --rest-api-id $API_ID --stage-name prod

# ----------------------------
# Clean up old deployments (optional)
# ----------------------------
for OLD_ID in $($awsonline apigateway get-rest-apis --query "items[?name=='$API_NAME'] | sort_by(@, &createdDate)[:-1].id" --output text); do
    echo "Deleting old API $OLD_ID"
    $awsonline apigateway delete-rest-api --rest-api-id $OLD_ID
done

# ----------------------------
# Print URLs
# ----------------------------
echo "API deployed! Access your endpoints here:"
echo "Start:  $(csurl 4566)/$API_ID/prod/_user_request_/start"
echo "Stop:   $(csurl 4566)/$API_ID/prod/_user_request_/stop"
echo "Status: $(csurl 4566)/$API_ID/prod/_user_request_/status"

rm lambda.zip