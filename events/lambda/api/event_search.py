import json
import boto3
from boto3.dynamodb.conditions import Key, And, Attr
import logging
import os
from datetime import datetime
from constant import ResponseCodes
from utils import EventJSONEncoder, json_response, get_signed_url

ddb = boto3.resource('dynamodb')
table = ddb.Table(os.environ['ENV_EVENT_TABLE_NAME'])
logging.getLogger().setLevel(logging.INFO)
logging.info('Loading search event lambda function')

def search(event, context):
    user_id = 'ap-northeast-1:750d5320-5447-4fc7-b211-397d3f952650'
    #event_category = event['headers']['eventcategory']
    event_category = 'thermal'
    #event_category = event['headers']['eventcategory']
    try:
        start_date_1 = datetime.now()
        logging.info("request : {}".format(str(event)))
        page_size = 10
        sorting = False
        body = json.loads(event['body'])
        events = None
        if 'PageSize' in body.keys():
            page_size = body['PageSize']
        if 'Sorting' in body.keys():
            sorting = body['Sorting'] == 'asc'
        lastEvaluatedKeys = []
        lastEvaluatedKey = None
        if 'FilterExpressions' not in body.keys():
            if body and 'LastEvaluatedKey' in body.keys():
                lastEvaluatedKey = body['LastEvaluatedKey']
                lastEvaluatedKeys.append(lastEvaluatedKey)
                events = table.query(KeyConditionExpression = Key("EventID").eq(user_id + '.' + event_category),
                                     Limit = page_size,
                                     ScanIndexForward = sorting,
                                     ExclusiveStartKey = lastEvaluatedKey
                                     )
            else:
                lastEvaluatedKeys.append(lastEvaluatedKey)
                events = table.query(KeyConditionExpression = Key("EventID").eq(user_id + '.' + event_category),
                                    Limit = page_size,
                                    ScanIndexForward = sorting
                                    )
            if 'LastEvaluatedKey' in events.keys():
                lastEvaluatedKey = events['LastEvaluatedKey']
                lastEvaluatedKeys.append(lastEvaluatedKey)
            for i in range(1,5):
                if lastEvaluatedKey != None:
                    next_events = table.query(KeyConditionExpression = Key("EventID").eq(user_id + '.' + event_category),
                                        Limit = page_size,
                                        ScanIndexForward = sorting,
                                        ExclusiveStartKey = lastEvaluatedKey
                                        )
                    if 'LastEvaluatedKey' in next_events.keys():
                        lastEvaluatedKey = next_events['LastEvaluatedKey']
                        lastEvaluatedKeys.append(next_events['LastEvaluatedKey'])
        elif 'FilterExpressions' in body.keys():
            filters = generateFilterExpression(body['FilterExpressions'])
            if body and 'LastEvaluatedKey' not in body.keys():
                lastEvaluatedKeys.append(lastEvaluatedKey)
                events = table.query(IndexName = filters['index'],
                                     KeyConditionExpression = Key(filters['key']).eq(user_id + '.' + event_category + '.' + filters['value']),
                                     Limit = page_size,
                                     ScanIndexForward = sorting
                                    )
            elif body and 'LastEvaluatedKey' in body.keys():
                lastEvaluatedKey = body['LastEvaluatedKey']
                lastEvaluatedKeys.append(lastEvaluatedKey)
                events = table.query(IndexName = filters['index'],
                                     KeyConditionExpression = Key(filters['key']).eq(user_id + '.' + event_category + '.' + filters['value']),
                                     Limit = page_size,
                                     ScanIndexForward = sorting,
                                     ExclusiveStartKey =  body['LastEvaluatedKey']
                                    )
            if 'LastEvaluatedKey' in events.keys():
                lastEvaluatedKey = events['LastEvaluatedKey']
                lastEvaluatedKeys.append(lastEvaluatedKey)
            for i in range(1,5):
                if lastEvaluatedKey != None:
                    next_events = table.query(IndexName = filters['index'],
                                        KeyConditionExpression = Key(filters['key']).eq(user_id + '.' + event_category + '.' + filters['value']),
                                        Limit = page_size,
                                        ScanIndexForward = sorting,
                                        ExclusiveStartKey = lastEvaluatedKey
                                        )
                    if 'LastEvaluatedKey' in next_events.keys():
                        lastEvaluatedKey = next_events['LastEvaluatedKey']
                        lastEvaluatedKeys.append(next_events['LastEvaluatedKey'])
        else:
            return json_response(ResponseCodes.EMPTY_PAYLOAD.value)
        if events != None:
            start_date_2 = datetime.now()
            events['LastEvaluatedKeys'] = lastEvaluatedKeys
            response = ResponseCodes.SUCCESS.value
            #events['Items'] = get_signed_url(events['Items'])
            start_date_3 = datetime.now()
            response['data'] = json.loads(json.dumps(events['Items'], cls=EventJSONEncoder))
            if 'LastEvaluatedKey' in events.keys():
                response['LastEvaluatedKeys'] = events['LastEvaluatedKeys']
            return json_response(response)
        else:
            json_response(ResponseCodes.EVENT_NOT_FOUND.value)

    except Exception as e:
        logging.error(e)
        return json_response(ResponseCodes.FAIL.value)

def generateFilterExpression(filterExpressions):
    zoneID = ''
    eventType = ''
    filters = {}
    for ex in filterExpressions :
        if 'EventType' == ex['key']:
            eventType = ex['value']
        if 'zoneID'  == ex['key']:
            zoneID = ex['value']
    if zoneID != '' and eventType != '':
        filters['value'] = zoneID + '.' + eventType
        filters['key'] = 'userID-eventCategory-zoneID-eventType'
        filters['index'] = 'userID-eventCategory-zoneID-eventType-EventDate-index'
    elif zoneID != '' and eventType == '':
        filters['value'] = zoneID
        filters['key'] = 'userID-eventCategory-zoneID'
        filters['index'] = 'userID-eventCategory-zoneID-EventDate-index'
    elif zoneID == '' and eventType != '':
        filters['value'] = eventType
        filters['key'] = 'userID-eventCategory-eventType'
        filters['index'] = 'userID-eventCategory-eventType-EventDate-index'
    return filters
