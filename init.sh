#!/bin/bash

export AWS_ENDPOINT_URL=http://localhost:4566

echo "Deploy Lambda"
make deploy-lambda

echo "Test API"
make test-all

echo "Done"
