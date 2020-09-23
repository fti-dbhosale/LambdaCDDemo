#!/usr/bin/env bash

UUID=`uuidgen`
NOW=`date "+%Y%m%d_%H%M%S"`
CODE_S3_PREFIX="${NOW}/${UUID}"

echo $CODE_S3_PREFIX
#aws lambda list-functions
