import json

def lambda_handler(event, context):
    response = 'Hello, This is a code pipeline demo '
    return {"statusCode": 200, "body": json.dumps(response)}
