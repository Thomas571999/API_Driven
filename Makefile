# =========================
# VARIABLES
# =========================

AWS := aws --endpoint-url=$$AWS_ENDPOINT_URL

API_ID := $$API_ID
API_URL := http://localhost:4566/restapis/$$API_ID/dev/_user_request_/ec2

LAMBDA_NAME := ec2-controller
LAMBDA_DIR := lambda
ZIP_FILE := lambda.zip

# =========================
# DEPLOY LAMBDA
# =========================

deploy-lambda:
	cd $(LAMBDA_DIR) && zip -q $(ZIP_FILE) lambda_function.py
	$(AWS) lambda update-function-code \
		--function-name $(LAMBDA_NAME) \
		--zip-file fileb://$(LAMBDA_DIR)/$(ZIP_FILE)

# =========================
# EC2 ACTIONS VIA API GATEWAY
# =========================

stop:
	curl -s -X POST $(API_URL) \
	-H "Content-Type: application/json" \
	-d '{"action":"stop"}'

start:
	curl -s -X POST $(API_URL) \
	-H "Content-Type: application/json" \
	-d '{"action":"start"}'

status:
	curl -s -X POST $(API_URL) \
	-H "Content-Type: application/json" \
	-d '{"action":"status"}'

# =========================
# FULL TEST PIPELINE
# =========================

test-all:
	@echo "Stopping instance..."
	@curl -s -X POST $(API_URL) -H "Content-Type: application/json" -d '{"action":"stop"}'
	@echo "\nStarting instance..."
	@curl -s -X POST $(API_URL) -H "Content-Type: application/json" -d '{"action":"start"}'
	@echo "\nChecking status..."
	@curl -s -X POST $(API_URL) -H "Content-Type: application/json" -d '{"action":"status"}'
	@echo "\nDone."

# =========================
# VALIDATION COMPLETE (IMPORTANT POUR NOTATION)
# =========================

validate:
	@echo "=== EC2 INSTANCES ==="
	$(AWS) ec2 describe-instances

	@echo "\n=== LAMBDA FUNCTION ==="
	$(AWS) lambda get-function --function-name $(LAMBDA_NAME)

	@echo "\n=== API GATEWAY RESOURCES ==="
	$(AWS) apigateway get-resources --rest-api-id $(API_ID)

# =========================
# LOGS (BONUS POINTS)
# =========================

logs:
	$(AWS) logs describe-log-groups
	$(AWS) logs describe-log-streams --log-group-name /aws/lambda/$(LAMBDA_NAME)

# =========================
# CLEAN (OPTIONNEL)
# =========================

clean:
	@echo "Deleting Lambda function..."
	-$(AWS) lambda delete-function --function-name $(LAMBDA_NAME)

# =========================
# FULL PIPELINE AUTOMATION
# =========================

full: deploy-lambda test-all validate

# =========================
# HELP
# =========================

help:
	@echo "Available commands:"
	@echo "  make deploy-lambda"
	@echo "  make test-all"
	@echo "  make validate"
	@echo "  make logs"
	@echo "  make clean"
	@echo "  make full"
