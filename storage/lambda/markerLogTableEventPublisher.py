import json
import os
import logging
import boto3

logging.getLogger().setLevel(logging.INFO)

def lambda_handler(event, context):
    logging.info("request : {}".format(str(event)))
    topic_arn = os.environ['ENV_TARGET_SNS_TOPIC_ARN']
    sns = boto3.client('sns')
    response = sns.publish(TopicArn = topic_arn,
    Message=json.dumps(event),
    )
    return True
