#!/usr/bin/env bash
AWS_PROFILE_OPTION=`create_aws_profile_option ${AWS_PROFILE}`
UUID=""
NOW=`date "+%Y%m%d_%H%M%S"`
CODE_S3_PREFIX="${NOW}/${UUID}"

echo $CODE_S3_PREFIX
echo $AWS_PROFILE_OPTION
#aws lambda list-functions
