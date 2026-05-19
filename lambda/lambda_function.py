import boto3
import os
import json

INSTANCE_ID = os.environ["INSTANCE_ID"]

ec2 = boto3.client(
    "ec2",
    endpoint_url="http://localhost.localstack.cloud:4566",
    region_name="us-east-1"
)

def lambda_handler(event, context):

    try:
        # 🔥 IMPORTANT: API Gateway wrapper support
        body = event

        if "body" in event and event["body"]:
            body = json.loads(event["body"])

        action = body.get("action")

        if action == "stop":
            ec2.stop_instances(InstanceIds=[INSTANCE_ID])
            return {
                "statusCode": 200,
                "body": json.dumps("Instance stopped")
            }

        if action == "start":
            ec2.start_instances(InstanceIds=[INSTANCE_ID])
            return {
                "statusCode": 200,
                "body": json.dumps("Instance started")
            }

        if action == "status":
            response = ec2.describe_instances(InstanceIds=[INSTANCE_ID])
            state = response["Reservations"][0]["Instances"][0]["State"]["Name"]

            return {
                "statusCode": 200,
                "body": json.dumps({"state": state})
            }

        return {
            "statusCode": 400,
            "body": json.dumps("Invalid action")
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps(str(e))
        }
