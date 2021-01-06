import json
import boto3
import os
import logging
from datetime import datetime, timedelta
from boto3.dynamodb.types import TypeDeserializer, TypeSerializer
from boto3.dynamodb.conditions import Key, And

dynamodb = boto3.resource("dynamodb")

event_table = dynamodb.Table(os.environ['ENV_EVENT_TABLE_NAME'])
print(event_table)
event_config_table = dynamodb.Table(os.environ['ENV_EVENT_CONFIG_TABLE_NAME'])
activitylog_table = dynamodb.Table(os.environ['ENV_ACTIVITYLOG_TABLE_NAME'])

valid_event_types = ("Watching", "TempAlarming", "face_detection", "mask_detection")

logging.info('Loading event dispatcher lambda function')

def from_dynamodb_to_json(item):
    d = TypeDeserializer()
    return {k: d.deserialize(value=v) for k, v in item.items()}

def is_valid_event_type(event_type):
    is_type_valid = event_type in valid_event_types
    logging.info("is event type valid : {}".format(str(is_type_valid)))
    return is_type_valid

def is_valid_event(event):
    event_date = datetime.strptime(event['payload']['DateTime'].split("+")[0], '%Y-%m-%d %H:%M:%S')
    event_days = (datetime.now() - event_date)
    is_valid = (event_days.days < int(os.environ['ENV_VALID_EVENT_DAYS']))
    logging.info("is event date valid : {}".format(str(is_valid)))
    return is_valid

def insert_into_dynamodb(event_json):
    logging.info('inserting to dynamodb table {}'.format(str(event_json)))
    status = False
    try:
        r = event_table.put_item(Item=event_json)
        print(r)
        status = True
        logging.info('record inserted successfully')
    except:
        logging.error("Failed to insert record")
        status = False
    return status

def get_event_target(event_json):
    logging.info("get_event_target for action: {}".format(event_json['payload']['Action']))
    try:
        response = event_config_table.get_item(Key={'EventType':event_json['payload']['Action']})
        logging.info('event config for event type {} is {}'.format(event_json['payload']['Action'], response['Item']))
        event_json['target'] = response['Item']['Action']
    except:
        logging.info("failed to get event_target for event type {} ".format(event_json['payload']['Action']))

    return event_json

def publish_to_sns(event_json):
    logging.info('Publishing json to SNS {}'.format(str(event_json)))
    topic_arn  = os.environ['ENV_TARGET_SNS_TOPIC_ARN']
    sns_client = boto3.client('sns')
    event_json = get_event_target(event_json)

    status = False
    try:
        sns_client.publish(TopicArn=topic_arn, Message=str(event_json), Subject="Event")
        logging.info("message published")
        status = True
    except Exception as e:
        logging.error(e)
        status = False
    return status

def get_activity_log(device_id):
    if "." not in device_id:
        device_id = str(device_id) + ".dispatch"
    else:
        device_id = device_id.split(".")[0] + ".dispatch"

    logging.info("Getting Activity log for device id {}".format(device_id))
    response = activitylog_table.query(KeyConditionExpression=Key('DeviceID').eq(device_id))
    items = response['Items']
    logging.info("Result from ActivityLog table for deviceID {} is {}".format(device_id, str(items)))
    if items:
        return items[0]
    else:
        return None

def handle_sns_event(event):
    for record in event['Records']:
        logging.info('handle_sns_event for record: {}'.format(record))
        if 'aws:dynamodb' == record['eventSource'] and 'INSERT' == record['eventName']:
            if record['dynamodb']['NewImage']:
                try:
                    new_item = record['dynamodb']['NewImage']
                    event_json = from_dynamodb_to_json(new_item)
                    activity_log = get_activity_log(event_json['DeviceID'])
                    user_id = activity_log['UserID']
                    event_json['UserID'] = user_id
                    event_json['OrganizationID'] = user_id
                    event_json['LogicalID'] = activity_log['LogicalID']
                    event_json['zoneID'] = activity_log['LogicalID']
                    event_json['StreamID'] = activity_log['LogicalID']
                    event_json['EventDate'] = event_json['payload']['DateTime']
                    event_json['EventType'] = event_json['payload']['Action']
                    event_json['EventID'] = str(event_json['UserID']) + "." + str(event_json['payload']['EventCatagory'])
                    event_json['EventCatagory'] = str(event_json['payload']['EventCatagory'])
                    event_json['userID-eventCategory-zoneID'] = user_id + "." + str(event_json['payload']['EventCatagory']) + "." + str(event_json['zoneID'])
                    event_json['userID-eventCategory-eventType'] = user_id + "." + str(event_json['payload']['EventCatagory']) + "." + str(event_json['EventType'])
                    event_json['userID-eventCategory-zoneID-eventType'] = user_id + "." + str(event_json['payload']['EventCatagory']) + "." + str(event_json['zoneID']) + "." + str(event_json['EventType'])   
                    event_json['userID-eventCategory-personID'] = user_id + "." + str(event_json['payload']['EventCatagory']) + "." + str(event_json['UserID'])
                    print(event_json)
                    print(user_id)
                    print(is_valid_event_type(event_json['payload']['Action']))
                    print(is_valid_event(event_json))
                    if (user_id and is_valid_event_type(event_json['payload']['Action']) and is_valid_event(event_json)):
                        status = insert_into_dynamodb(event_json)
                        if(status):
                            publish_to_sns(event_json)
                except Exception as e:
                    logging.error(e)
            else:
                logging.info("Invalid event type expecting NewImage")
        else:
            logging.info("Invalid event source or eventName expecting aws:dynamodb and INSERT but was {} and {}".format(record['eventSource'], record['eventName']))
    return True

def lambda_handler(event, context):
    logging.getLogger().setLevel(logging.INFO)
    for record in event['Records']:
        handle_sns_event(json.loads(record['Sns']['Message']))
    return True
