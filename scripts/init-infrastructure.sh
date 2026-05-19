#!/bin/bash

# =============================================================
# API-DRIVEN Infrastructure Initialization Script
# =============================================================

set -e

# Source environment
if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | grep -v '^$' | xargs)
fi

export AWS_ENDPOINT_URL="${AWS_ENDPOINT_URL:-http://localhost:4566}"
export AWS_REGION="${AWS_REGION:-us-east-1}"

AWS="aws --endpoint-url=$AWS_ENDPOINT_URL"
LAMBDA_NAME="ec2-controller"
LAMBDA_DIR="lambda"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   API-DRIVEN Infrastructure Initialization${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

# Step 1: Create EC2 Instance
echo -e "${BLUE}Step 1: Creating EC2 instance...${NC}"
if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "null" ]; then
    INSTANCE=$(${AWS} ec2 run-instances \
        --image-id ami-12c6146b \
        --instance-type t2.micro \
        --region us-east-1 \
        --query 'Instances[0].InstanceId' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$INSTANCE" ] && [ "$INSTANCE" != "null" ]; then
        echo -e "${GREEN}✓ EC2 Instance created: $INSTANCE${NC}"
        sed -i "s/INSTANCE_ID=.*/INSTANCE_ID=$INSTANCE/" .env
        INSTANCE_ID=$INSTANCE
    else
        echo -e "${RED}✗ Failed to create EC2 instance${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}ℹ Using existing instance from .env: $INSTANCE_ID${NC}"
fi
echo ""

# Step 2: Create Lambda Role
echo -e "${BLUE}Step 2: Creating Lambda role...${NC}"
ROLE=$(${AWS} iam get-role --role-name lambda-role --query 'Role.Arn' --output text 2>/dev/null || echo "")

if [ -z "$ROLE" ] || [ "$ROLE" = "null" ]; then
    ROLE=$(${AWS} iam create-role \
        --role-name lambda-role \
        --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \
        --query 'Role.Arn' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$ROLE" ] && [ "$ROLE" != "null" ]; then
        echo -e "${GREEN}✓ Lambda role created: $ROLE${NC}"
    else
        echo -e "${RED}✗ Failed to create Lambda role${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}ℹ Using existing role: $ROLE${NC}"
fi
echo ""

# Step 3: Create Lambda Function
echo -e "${BLUE}Step 3: Creating Lambda function...${NC}"
cd $LAMBDA_DIR
zip -q lambda.zip lambda_function.py
cd ..

LAMBDA=$(${AWS} lambda get-function --function-name $LAMBDA_NAME --query 'Configuration.FunctionArn' --output text 2>/dev/null || echo "")

if [ -z "$LAMBDA" ] || [ "$LAMBDA" = "null" ]; then
    LAMBDA=$(${AWS} lambda create-function \
        --function-name $LAMBDA_NAME \
        --runtime python3.12 \
        --role arn:aws:iam::000000000000:role/lambda-role \
        --handler lambda_function.lambda_handler \
        --zip-file fileb://./$LAMBDA_DIR/lambda.zip \
        --environment "Variables={INSTANCE_ID=$INSTANCE_ID}" \
        --timeout 30 \
        --memory-size 256 \
        --query 'FunctionArn' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$LAMBDA" ] && [ "$LAMBDA" != "null" ]; then
        echo -e "${GREEN}✓ Lambda function created: $LAMBDA${NC}"
    else
        echo -e "${RED}✗ Failed to create Lambda function${NC}"
        exit 1
    fi
else
    # Update environment variable
    ${AWS} lambda update-function-configuration \
        --function-name $LAMBDA_NAME \
        --environment "Variables={INSTANCE_ID=$INSTANCE_ID}" \
        > /dev/null 2>&1
    echo -e "${YELLOW}ℹ Using existing function: $LAMBDA${NC}"
fi
echo ""

# Step 4: Create API Gateway
echo -e "${BLUE}Step 4: Creating API Gateway...${NC}"
if [ -z "$API_ID" ] || [ "$API_ID" = "null" ]; then
    API=$(${AWS} apigateway create-rest-api \
        --name ec2-controller-api \
        --description "API to control EC2 via Lambda" \
        --query 'id' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$API" ] && [ "$API" != "null" ]; then
        echo -e "${GREEN}✓ API Gateway created: $API${NC}"
        sed -i "s/API_ID=.*/API_ID=$API/" .env
        API_ID=$API
    else
        echo -e "${RED}✗ Failed to create API Gateway${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}ℹ Using existing API: $API_ID${NC}"
fi
echo ""

# Step 5: Configure API Gateway Resources
echo -e "${BLUE}Step 5: Configuring API Gateway resources...${NC}"

# Get root resource
ROOT=$(${AWS} apigateway get-resources \
    --rest-api-id $API_ID \
    --query 'items[0].id' \
    --output text 2>/dev/null)

# Create /ec2 resource
RESOURCE=$(${AWS} apigateway get-resources \
    --rest-api-id $API_ID \
    --query 'items[?pathPart==`ec2`].id' \
    --output text 2>/dev/null || echo "")

if [ -z "$RESOURCE" ]; then
    RESOURCE=$(${AWS} apigateway create-resource \
        --rest-api-id $API_ID \
        --parent-id $ROOT \
        --path-part ec2 \
        --query 'id' \
        --output text 2>/dev/null)
    echo -e "${GREEN}✓ API resource /ec2 created: $RESOURCE${NC}"
else
    echo -e "${YELLOW}ℹ API resource /ec2 already exists: $RESOURCE${NC}"
fi

# Create POST method
${AWS} apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE \
    --http-method POST \
    --authorization-type NONE \
    > /dev/null 2>&1

# Create Lambda integration
${AWS} apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:000000000000:function:ec2-controller/invocations \
    > /dev/null 2>&1

# Create deployment
DEPLOYMENT=$(${AWS} apigateway create-deployment \
    --rest-api-id $API_ID \
    --stage-name dev \
    --query 'id' \
    --output text 2>/dev/null || echo "")

if [ -n "$DEPLOYMENT" ] && [ "$DEPLOYMENT" != "null" ]; then
    echo -e "${GREEN}✓ API deployed: $DEPLOYMENT${NC}"
fi

# Grant Lambda permission
${AWS} lambda add-permission \
    --function-name $LAMBDA_NAME \
    --statement-id apigateway-access \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    > /dev/null 2>&1

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓✓✓ Initialization Completed Successfully! ✓✓✓${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Configuration Summary:${NC}"
echo -e "${YELLOW}  AWS Endpoint:${NC} $AWS_ENDPOINT_URL"
echo -e "${YELLOW}  Region:${NC} $AWS_REGION"
echo -e "${YELLOW}  API Gateway ID:${NC} $API_ID"
echo -e "${YELLOW}  EC2 Instance ID:${NC} $INSTANCE_ID"
echo -e "${YELLOW}  Lambda Function:${NC} $LAMBDA_NAME"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Run:  make test-all   (test the complete pipeline)"
echo "  2. Run:  make info       (view your configuration)"
echo "  3. Run:  make help       (see all available commands)"
echo ""
