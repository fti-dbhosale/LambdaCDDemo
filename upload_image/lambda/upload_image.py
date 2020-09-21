import json
import base64
import boto3
from utils import json_response

BUCKET_NAME = 'images-api-upload'

def put(event, context):
    print(event)
    file_content = base64.b64decode(event['body'])
    file_path = 'abc.JPG'
    s3 = boto3.client('s3')
    try:
        s3_response = s3.put_object(Bucket=BUCKET_NAME, Key=file_path, Body=file_content)
    except Exception as e:
        raise IOError(e)
    response = { 'body': {
            'file_path': BUCKET_NAME + "/" + file_path
                }
            }
    return json_response(response)
        
