#!/usr/bin/env bash
#AWS_PROFILE_OPTION=`create_aws_profile_option ${AWS_PROFILE}`
UUID=""
STACK_NAME="fti-events"
LAMBDA_VERSION="1.0"
REALM="dev"
INSTANCE="dev"
DEFAULT_PYTHON_RUNTIME="python3.8"
NOW=`date "+%Y%m%d_%H%M%S"`
CODE_S3_PREFIX=${NOW}
CODE_UPLOAD_BUCKET="demo-lambda-pipeline"
REGION="ap-south-1"
CODE_S3_PREFIX="${CODE_S3_PREFIX}.events-function"
CloudFrontKeyPairFileKey=""
CloudFrontDeviceImagesBucketDomainName=""
CloudFrontKeyPairID=""
CloudFrontKeyPairBucket=""

CODE_ZIP="events-function.zip"

deploy(){
  rm ./events/cloudformation/${CODE_ZIP}
  cd ./events/lambda/api

  pip3 install -r ./requirements.txt --target ./
  cp -r /root/LambdaCDDemo/events/lambda/dispatcher dispatcher
  zip -r ../../cloudformation/${CODE_ZIP} .

  ls
  cd ../../cloudformation
  ls
  aws --region ${REGION} s3 cp ${CODE_ZIP} s3://${CODE_UPLOAD_BUCKET}/${CODE_S3_PREFIX}/${CODE_ZIP}

  aws --region ${REGION} cloudformation deploy \
      --template-file events.yaml \
      --s3-bucket ${CODE_UPLOAD_BUCKET} \
      --s3-prefix ${CODE_S3_PREFIX} \
      --stack-name ${STACK_NAME} \
      --capabilities CAPABILITY_NAMED_IAM \
      --no-fail-on-empty-changeset \
      --parameter-overrides \
      InstanceName=${INSTANCE} \
      Version=${LAMBDA_VERSION} \
      LambdaCodeS3Bucket=${CODE_UPLOAD_BUCKET} \
      LambdaCodeS3Key="${CODE_S3_PREFIX}/${CODE_ZIP}" \
      RealmName=${REALM} \
      PythonRuntime=${DEFAULT_PYTHON_RUNTIME} \
      CloudFrontKeyPairID=${CLOUD_FRONT_KEY_PAIR_ID} \
      CloudFrontKeyPairBucket=${CLOUD_FRONT_KEY_PAIR_BUCKET} \
      CloudFrontKeyPairFileKey=${CLOUD_FRONT_KEY_PAIR_FILE_KEY}
}

deploy
