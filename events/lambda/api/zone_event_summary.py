import json
import boto3
from boto3.dynamodb.conditions import Key, And, Attr
import logging
import os
from datetime import datetime, timedelta
from pytz import timezone
from constant import ResponseCodes, DATETIME_FORMAT, TIMEZONE
from utils import EventJSONEncoder, json_response, get_signed_url

ddb = boto3.resource('dynamodb')
table = ddb.Table(os.environ['ENV_EVENT_TABLE_NAME'])
logging.getLogger().setLevel(logging.INFO)
logging.info('Loading event api lambda function')

def get(event, context):
    user_id = event['requestContext']['identity']['cognitoIdentityId']
    event_category = event['headers']['eventcategory']
    today = datetime.now().astimezone(timezone(TIMEZONE))
    yesterday = today - timedelta(days = 1)
    today = today.strftime(DATETIME_FORMAT)
    yesterday = yesterday.strftime(DATETIME_FORMAT)

    try:
        SnapshotSignedUrl = None
        body = json.loads(event['body'])
        logging.info("is even type valid : {}".format(str(event)))
        zone = {'zoneID': body['lid'],'ZoneName': body['name']}
        Last24HoursCount = None
        LastDetectionTime = ''
        events = table.query(KeyConditionExpression = Key("EventID").eq(user_id + '.' + event_category) & Key('EventDate').between(yesterday, today),
                             ScanIndexForward = False,
                             FilterExpression = Attr('zoneID').eq(zone['zoneID'])
                             )
        zone['Last24HoursCount'] = events['Count']
        if events['Count'] > 0 :
            event = get_signed_url(events['Items'][:1])
            SnapshotSignedUrl = event[0]['SnapshotSignedUrl']
            LastDetectionTime = events['Items'][0]['EventDate']
        zone['LastDetectionTime'] = LastDetectionTime
        zone['SnapshotSignedUrl'] = SnapshotSignedUrl
        if zone:
            response = ResponseCodes.SUCCESS.value
            response['data'] = zone
            return json_response(response)
        else:
            return json_response(ResponseCodes.EVENT_NOT_FOUND.value)
        return json_response(ResponseCodes.EVENT_NOT_FOUND.value)
    except Exception as e:
        logging.error(e)
        return json_response(ResponseCodes.FAIL.value)

