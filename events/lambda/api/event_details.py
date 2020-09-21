import json
import boto3
from boto3.dynamodb.conditions import Key, And, Attr
import logging
import os
from constant import ResponseCodes
from utils import EventJSONEncoder, json_response, get_signed_url

ddb = boto3.resource('dynamodb')
table = ddb.Table(os.environ['ENV_EVENT_TABLE_NAME'])
logging.getLogger().setLevel(logging.INFO)
logging.info('Loading  get event details lambda function')

def get(event, context):
    logging.info("request : {}".format(str(event)))
    #user_id = event['requestContext']['identity']['cognitoIdentityId']
    user_id = 'ap-northeast-1:750d5320-5447-4fc7-b211-397d3f952650'
    #event_category = event['headers']['eventcategory']
    event_category = 'thermal'
    event_id= user_id + '.' + event_category
    try:
        body = json.loads(event['body'])
        if 'EventID' in body.keys() and 'EventDate' in body.keys() and body["EventID"] == event_id :
            logging.info("is even type valid : {}".format(str(event)))
            key = {"EventID" : body["EventID"],"EventDate" : body["EventDate"]}
            event = json.loads(json.dumps(table.get_item(Key = key).get('Item'), cls = EventJSONEncoder))
            event = get_signed_url([event])[0]
            if event:
                response = ResponseCodes.SUCCESS.value
                response['data'] = event
                return json_response(response)
            else:
                return json_response(ResponseCodes.EVENT_NOT_FOUND.value)
        else:
            return json_response(ResponseCodes.EVENT_NOT_FOUND.value)
    except Exception as e:
        logging.error(e)
        return json_response(ResponseCodes.FAIL.value)
