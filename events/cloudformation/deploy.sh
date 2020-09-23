#!/usr/bin/env bash
#AWS_PROFILE_OPTION=`create_aws_profile_option ${AWS_PROFILE}`
UUID=""
NOW=`date "+%Y%m%d_%H%M%S"`
CODE_S3_PREFIX="${NOW}/${UUID}"

echo $CODE_S3_PREFIX
echo $AWS_PROFILE
#aws lambda list-functions
CODE_ZIP="events-function.zip"
ls
sam --info
sam build
 cd ./events/lambda/api
 #run zip -q ../../cloudformation/${CODE_ZIP} \
 ls
 -r \
 . \
 ../dispatcher/



cd ../
ls
