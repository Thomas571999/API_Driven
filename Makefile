# =========================
# API-DRIVEN MAKEFILE
# Orchestration de services AWS via API Gateway & Lambda
# =========================

.PHONY: help setup init check status start stop logs deploy-lambda test-all validate full clean env-check info logs-tail

# Load environment from .env file
SHELL := /bin/bash
-include .env
export

# =========================
# VARIABLES
# =========================

LAMBDA_NAME := ec2-controller
LAMBDA_DIR := lambda
ZIP_FILE := lambda.zip

# Color output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# =========================
# SETUP & INITIALIZATION
# =========================

setup: env-check
	@echo "$(BLUE)✓ Environment variables loaded from .env$(NC)"
	@echo "$(BLUE)✓ AWS Endpoint: $(AWS_ENDPOINT_URL)$(NC)"
	@echo "$(BLUE)✓ API Gateway ID: $(API_ID)$(NC)"
	@echo "$(BLUE)✓ EC2 Instance ID: $(INSTANCE_ID)$(NC)"

env-check:
	@if [ -z "$(AWS_ENDPOINT_URL)" ]; then \
		echo "$(RED)✗ AWS_ENDPOINT_URL not set$(NC)"; exit 1; \
	fi
	@if [ -z "$(API_ID)" ]; then \
		echo "$(RED)✗ API_ID not set$(NC)"; exit 1; \
	fi
	@if [ -z "$(INSTANCE_ID)" ]; then \
		echo "$(RED)✗ INSTANCE_ID not set$(NC)"; exit 1; \
	fi

init:
	@bash scripts/init-infrastructure.sh

# =========================
# DEPLOYMENT
# =========================

deploy-lambda: env-check
	@echo "$(BLUE)→ Deploying Lambda function...$(NC)"
	cd $(LAMBDA_DIR) && zip -q $(ZIP_FILE) lambda_function.py && cd ..
	aws --endpoint-url=$(AWS_ENDPOINT_URL) lambda update-function-code \
		--function-name $(LAMBDA_NAME) \
		--zip-file fileb://$(LAMBDA_DIR)/$(ZIP_FILE)
	@echo "$(GREEN)✓ Lambda function deployed$(NC)"

# =========================
# EC2 ACTIONS VIA API GATEWAY
# =========================

status: env-check
	@echo "$(BLUE)→ Fetching instance status...$(NC)"
	@curl -s -X POST http://localhost:4566/restapis/$(API_ID)/dev/_user_request_/ec2 \
	-H "Content-Type: application/json" \
	-d '{"action":"status"}' | jq '.' 2>/dev/null || curl -s -X POST http://localhost:4566/restapis/$(API_ID)/dev/_user_request_/ec2 \
	-H "Content-Type: application/json" \
	-d '{"action":"status"}'

stop: env-check
	@echo "$(YELLOW)→ Stopping EC2 instance...$(NC)"
	@curl -s -X POST http://localhost:4566/restapis/$(API_ID)/dev/_user_request_/ec2 \
	-H "Content-Type: application/json" \
	-d '{"action":"stop"}'
	@echo ""
	@sleep 1 && $(MAKE) status

start: env-check
	@echo "$(YELLOW)→ Starting EC2 instance...$(NC)"
	@curl -s -X POST http://localhost:4566/restapis/$(API_ID)/dev/_user_request_/ec2 \
	-H "Content-Type: application/json" \
	-d '{"action":"start"}'
	@echo ""
	@sleep 1 && $(MAKE) status

# =========================
# CHECK INFRASTRUCTURE
# =========================

check: env-check
	@echo "$(BLUE)=== Infrastructure Status ====$(NC)"
	@echo ""
	@echo "$(BLUE)→ EC2 Instances:$(NC)"
	@aws --endpoint-url=$(AWS_ENDPOINT_URL) ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType]' --output table
	@echo ""
	@echo "$(BLUE)→ Lambda Function:$(NC)"
	@aws --endpoint-url=$(AWS_ENDPOINT_URL) lambda get-function --function-name $(LAMBDA_NAME) --query 'Configuration.[FunctionName,Runtime,CodeSize]' --output table
	@echo ""
	@echo "$(BLUE)→ API Gateway:$(NC)"
	@aws --endpoint-url=$(AWS_ENDPOINT_URL) apigateway get-rest-api --rest-api-id $(API_ID) --query '[Id,Name,CreatedDate]' --output table

# =========================
# TESTING PIPELINE
# =========================

test-all: env-check
	@echo "$(BLUE)==== Full Test Pipeline ====$(NC)"
	@echo ""
	@echo "$(YELLOW)1/3 Stopping instance...$(NC)"
	@curl -s -X POST http://localhost:4566/restapis/$(API_ID)/dev/_user_request_/ec2 -H "Content-Type: application/json" -d '{"action":"stop"}' | jq '.' 2>/dev/null || curl -s -X POST http://localhost:4566/restapis/$(API_ID)/dev/_user_request_/ec2 -H "Content-Type: application/json" -d '{"action":"stop"}'
	@sleep 2
	@echo ""
	@echo "$(YELLOW)2/3 Starting instance...$(NC)"
	@curl -s -X POST http://localhost:4566/restapis/$(API_ID)/dev/_user_request_/ec2 -H "Content-Type: application/json" -d '{"action":"start"}' | jq '.' 2>/dev/null || curl -s -X POST http://localhost:4566/restapis/$(API_ID)/dev/_user_request_/ec2 -H "Content-Type: application/json" -d '{"action":"start"}'
	@sleep 2
	@echo ""
	@echo "$(YELLOW)3/3 Checking status...$(NC)"
	@curl -s -X POST http://localhost:4566/restapis/$(API_ID)/dev/_user_request_/ec2 -H "Content-Type: application/json" -d '{"action":"status"}' | jq '.' 2>/dev/null || curl -s -X POST http://localhost:4566/restapis/$(API_ID)/dev/_user_request_/ec2 -H "Content-Type: application/json" -d '{"action":"status"}'
	@echo ""
	@echo "$(GREEN)✓ All tests completed$(NC)"

# =========================
# VALIDATION
# =========================

validate: env-check
	@echo "$(BLUE)==== Complete Validation ====$(NC)"
	@echo ""
	@echo "$(BLUE)→ Checking EC2 instances...$(NC)"
	@aws --endpoint-url=$(AWS_ENDPOINT_URL) ec2 describe-instances --output table | head -20
	@echo ""
	@echo "$(BLUE)→ Checking Lambda function...$(NC)"
	@aws --endpoint-url=$(AWS_ENDPOINT_URL) lambda get-function --function-name $(LAMBDA_NAME) --query 'Configuration.[FunctionName,Runtime,Handler,Timeout,MemorySize]' --output table
	@echo ""
	@echo "$(BLUE)→ Checking API Gateway resources...$(NC)"
	@aws --endpoint-url=$(AWS_ENDPOINT_URL) apigateway get-resources --rest-api-id $(API_ID) --query 'items[*].[id,pathPart,path]' --output table

# =========================
# LOGGING & MONITORING
# =========================

logs: env-check
	@echo "$(BLUE)=== Lambda Logs ====$(NC)"
	@aws --endpoint-url=$(AWS_ENDPOINT_URL) logs describe-log-groups --query 'logGroups[*].logGroupName' --output text | grep lambda
	@echo ""
	@echo "$(BLUE)→ Recent log streams:$(NC)"
	@aws --endpoint-url=$(AWS_ENDPOINT_URL) logs describe-log-streams --log-group-name /aws/lambda/$(LAMBDA_NAME) --order-by LastEventTime --descending --max-items 5 --query 'logStreams[*].[logStreamName,lastEventTimestamp]' --output table 2>/dev/null || echo "No log streams yet"

logs-tail: env-check
	@echo "$(BLUE)→ Tailing Lambda logs (last 20 lines)...$(NC)"
	@aws --endpoint-url=$(AWS_ENDPOINT_URL) logs tail /aws/lambda/$(LAMBDA_NAME) --follow 2>/dev/null || echo "$(RED)CloudWatch Logs not available$(NC)"

# =========================
# UTILITIES
# =========================

info: env-check
	@echo "$(BLUE)==== Project Information ====$(NC)"
	@echo ""
	@echo "$(YELLOW)AWS Configuration:$(NC)"
	@echo "  Endpoint: $${AWS_ENDPOINT_URL}"
	@echo "  Region: $${AWS_REGION}"
	@echo ""
	@echo "$(YELLOW)Infrastructure IDs:$(NC)"
	@echo "  API Gateway ID: $${API_ID}"
	@echo "  EC2 Instance ID: $${INSTANCE_ID}"
	@echo "  Lambda Function: $(LAMBDA_NAME)"
	@echo ""
	@echo "$(YELLOW)API Endpoint:$(NC)"
	@echo "  URL: $(API_URL)"
	@echo "  Method: POST"
	@echo "  Actions: start, stop, status"

# =========================
# CLEANUP
# =========================

clean: env-check
	@echo "$(RED)⚠ Cleaning up resources...$(NC)"
	@read -p "Are you sure? This will delete the Lambda function. (y/n) " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		aws --endpoint-url=$(AWS_ENDPOINT_URL) lambda delete-function --function-name $(LAMBDA_NAME) 2>/dev/null && echo "$(GREEN)✓ Lambda function deleted$(NC)" || echo "$(YELLOW)✓ Function was already deleted$(NC)"; \
	fi

# =========================
# PIPELINE AUTOMATION
# =========================

full: setup deploy-lambda test-all validate
	@echo ""
	@echo "$(GREEN)✓ Full pipeline completed successfully!$(NC)"
	@echo ""
	@$(MAKE) info

# =========================
# HELP
# =========================

help:
	@echo "$(BLUE)╔════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║         API-DRIVEN INFRASTRUCTURE - Makefile Help         ║$(NC)"
	@echo "$(BLUE)╚════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(YELLOW)🚀 First Time Setup:$(NC)"
	@echo "  make init           - Initialize all infrastructure (EC2, Lambda, API Gateway)"
	@echo ""
	@echo "$(YELLOW)Setup & Configuration:$(NC)"
	@echo "  make setup          - Load and verify environment variables"
	@echo "  make info           - Display project configuration"
	@echo ""
	@echo "$(YELLOW)Deployment:$(NC)"
	@echo "  make deploy-lambda  - Update Lambda function code"
	@echo ""
	@echo "$(YELLOW)EC2 Control (via API):$(NC)"
	@echo "  make start          - Start EC2 instance"
	@echo "  make stop           - Stop EC2 instance"
	@echo "  make status         - Get instance status"
	@echo ""
	@echo "$(YELLOW)Testing & Validation:$(NC)"
	@echo "  make check          - Quick infrastructure check"
	@echo "  make test-all       - Run full test pipeline"
	@echo "  make validate       - Complete validation"
	@echo ""
	@echo "$(YELLOW)Monitoring:$(NC)"
	@echo "  make logs           - Show Lambda log groups"
	@echo "  make logs-tail      - Tail Lambda logs in real-time"
	@echo ""
	@echo "$(YELLOW)Automation:$(NC)"
	@echo "  make full           - Execute complete pipeline (setup → deploy → test → validate)"
	@echo "  make clean          - Delete Lambda function"
	@echo ""
	@echo "$(YELLOW)Help:$(NC)"
	@echo "  make help           - Show this help message"
	@echo ""
