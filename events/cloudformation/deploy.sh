#!/usr/bin/env bash
#AWS_PROFILE_OPTION=`create_aws_profile_option ${AWS_PROFILE}`
UUID=""
NOW=`date "+%Y%m%d_%H%M%S"`
CODE_S3_PREFIX="${NOW}/${UUID}"
CODE_UPLOAD_BUCKET="demo-lambda-pipeline"
REGION="ap-south-1"
CODE_S3_PREFIX="events-function"
echo $CODE_S3_PREFIX
echo $AWS_PROFILE
#aws lambda list-functions
CODE_ZIP="events-function.zip"
 rm ./cloudformation/${CODE_ZIP}

 cd ./events/lambda/api
 pip3 install -r ./requirements.txt --target ./
 zip -r ../../cloudformation/${CODE_ZIP} .
 ls
 . \
 ../dispatcher/
aws --region ${REGION} s3 cp ../../cloudformation${CODE_ZIP} s3://${CODE_UPLOAD_BUCKET}/${CODE_S3_PREFIX}/${CODE_ZIP}
cd ../../cloudformation
ls

cd ../
ls
