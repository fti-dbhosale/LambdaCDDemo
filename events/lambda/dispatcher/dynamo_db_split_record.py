import json
import boto3
import os
import logging
from datetime import datetime, timedelta
from boto3.dynamodb.types import TypeDeserializer, TypeSerializer
from boto3.dynamodb.conditions import Key, And

sqs = boto3.client('sqs')
queue_url = os.environ['TARGET_SQS']
def lambda_handler(event, context):
    logging.getLogger().setLevel(logging.INFO)
    print(event)
    for record in event['Records']:
        if 'aws:sns' == record['EventSource'] and record['Sns']['Message']:
            response = sqs.send_message(
                QueueUrl=queue_url,
                DelaySeconds=10,
                MessageBody=(record['Sns']['Message']))
