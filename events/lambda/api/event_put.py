import json
import boto3
from boto3.dynamodb.conditions import Key, And, Attr
import logging
import os
from constant import ResponseCodes
from utils import EventJSONEncoder, json_response, get_signed_url

ddb = boto3.resource('dynamodb')
table = ddb.Table(os.environ['ENV_MARKER_LOG_TABLE_NAME'])
print(table)
logging.getLogger().setLevel(logging.INFO)
logging.info('Loading  get event details lambda function')

def put(event, context):
    body = json.loads(event['body'])
    print(body)
    try:
        if body:
            table.put_item(Item = body)
            return json_response(ResponseCodes.SUCCESS.value)
        else:
            return json_response(ResponseCodes.EMPTY_PAYLOAD.value)
    except Exception as e:
        print(e)
        return json_response(ResponseCodes.FAIL.value)
