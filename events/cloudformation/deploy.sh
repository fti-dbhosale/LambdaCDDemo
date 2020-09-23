#!/usr/bin/env bash

NOW=`date "+%Y%m%d_%H%M%S"`
CODE_S3_PREFIX="${NOW}"

${CODE_S3_PREFIX}
aws lambda list-functions
