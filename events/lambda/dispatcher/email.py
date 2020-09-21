from __future__ import print_function

def lambda_handler(event, context):
    print('Loading email lambda function')
    for record in event['Records']:
        print ("test")
        payload=record["body"]
        print(str(payload))

    return {
        'status': 200,
        'body':'email lambda handler function invoked'
    }