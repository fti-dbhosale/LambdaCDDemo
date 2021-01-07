import json
import boto3
import os
import logging
from datetime import datetime, timedelta
from boto3.dynamodb.types import TypeDeserializer, TypeSerializer
from boto3.dynamodb.conditions import Key, And


def lambda_handler(event, context):
    logging.getLogger().setLevel(logging.INFO)
    print(event)
    return True
