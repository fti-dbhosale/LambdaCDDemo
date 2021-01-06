import decimal
import json
import boto3
import logging
from boto3.dynamodb.conditions import Key
from boto.cloudfront.distribution import Distribution
from boto.cloudfront import CloudFrontConnection
from botocore.client import BaseClient
from botocore.signers import CloudFrontSigner
from datetime import datetime, timedelta
import rsa
from urllib.parse import quote
import os
from constant import CLOUD_FRONT_BASE_PROTOCOL


class EventJSONEncoder(json.JSONEncoder):

    def default(self, obj):
        if isinstance(obj, decimal.Decimal):
            return int(obj)
        return super(EventJSONEncoder, self).default(obj)


def json_response(message, status_code=200):
    return {
        'statusCode': str(status_code),
        'body': json.dumps(message),
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
    }

class CloudFrontUtil:

    def __init__(self, key_id, key_file, expire_date, bucket, cf_domain_url):
        self.key_id = key_id
        self.expire_date = expire_date
        self.bucket = bucket
        self.key_file = key_file
        self.cf_domain_url = cf_domain_url
        s3_client = boto3.client('s3')
        try:
            self.private_key = s3_client.get_object(Bucket=bucket, Key=key_file)['Body'].read()
        except Exception as e:
            logging.error(e)

    def rsa_signer(self, message):
        return rsa.sign(message, rsa.PrivateKey.load_pkcs1(self.private_key), 'SHA-1')

    def get_s3_url(self, events):
        try:
            cf_signer = CloudFrontSigner(self.key_id, self.rsa_signer)
            for event in events:
                file_name = event['payload']['Snapshot']
                file_name = quote(file_name.encode("utf-8"))
                s3_image_url = self.cf_domain_url + "/" + event['Destination']['S3']['Prefix'] + file_name
                event['SnapshotSignedUrl'] = cf_signer.generate_presigned_url(s3_image_url, date_less_than=self.expire_date)
            return events
        except Exception as e:
            logging.error(e)
        return events

def get_signed_url(events):
    expire_date = datetime.now() + timedelta(minutes=5410)
    key_id = os.environ['ENV_CloudFrontKeyPairID']
    key_file = os.environ['ENV_CloudFrontKeyPairFileKey']
    bucket = os.environ['ENV_CloudFrontKeyPairBucket']
    cf_domain_url = CLOUD_FRONT_BASE_PROTOCOL + os.environ['ENV_CloudFrontDeviceImagesBucketDomainName']
    cf = CloudFrontUtil(key_id, key_file, expire_date, bucket, cf_domain_url)
    return cf.get_s3_url(events)
