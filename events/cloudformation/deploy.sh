#!/usr/bin/env bash
#AWS_PROFILE_OPTION=`create_aws_profile_option ${AWS_PROFILE}`
UUID=""
NOW=`date "+%Y%m%d_%H%M%S"`
CODE_S3_PREFIX="${NOW}/${UUID}"

echo $CODE_S3_PREFIX
echo $AWS_PROFILE
#aws lambda list-functions
CODE_ZIP="events-function.zip"
 pushd ../
 rm ./cloudformation/${CODE_ZIP}

 pushd ./lambda/api
 pip3 install -r ./requirements.txt --target ./
 run zip -q ../../cloudformation/${CODE_ZIP} \
 -r \
 . \
 ../dispatcher/
 popd

ls
cd ../
ls 
