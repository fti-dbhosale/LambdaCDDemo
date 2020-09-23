#!/bin/bash

function dir_error() {
    echo "Please execute on the directory where the script is located."
    exit 1
}

function usage() {
    cat <<_EOT_
Usage:
    $0
    [--aws-profile <value>]
    [--help]
Options:
    --aws-profile (string)
        AWS CLI profile name.
    --help
        Show usage.
_EOT_
    exit 1
}


function validate_dependencies() {
    validate_common_dependencies

    which uuidgen || {
        echo "Please install uuidgen"
        exit 1
    }
}

PARAMETER_FILE_URL=""
PARAMETER_LOCAL_FILE_PATH=""
AWS_PROFILE=""
DEFAULT_PYTHON_RUNTIME=""

while true; do
    case "$1" in
        --aws-profile ) validate_argument $2; AWS_PROFILE=$2; shift 2 ;;
        --help ) usage; shift ;;
        -* | --* ) usage; shift; break ;;
        * ) shift; break ;;
    esac
done

# Args validation

# Dependencies validation
validate_dependencies

# Get parameter
CODE_UPLOAD_BUCKET=CODE_UPLOAD_BUCKET
INSTANCE=INSTANCE
REALM=dev
REGION=ap-south-1
LAMBDA_VERSION=1.0
STACK_NAME=fti-events
DEFAULT_PYTHON_RUNTIME= python3.8
CLOUD_FRONT_KEY_PAIR_ID=CLOUD_FRONT_KEY_PAIR_ID
CLOUD_FRONT_KEY_PAIR_BUCKET=CLOUD_FRONT_KEY_PAIR_BUCKET
CLOUD_FRONT_KEY_PAIR_FILE_KEY=CLOUD_FRONT_KEY_PAIR_FILE_KEY
# TODO
# When deleting getBucketName () in S3Util.js, delete this line as well.
S3_BUCKET_NAME_PREFIX=S3_BUCKET_NAME_PREFIX

# Crean up
rm -fr ${JSON_PARAMS_FILE}

# Parameter validation

# AWS Profile
AWS_PROFILE_OPTION=`create_aws_profile_option ${AWS_PROFILE}`

if [ -z "${REALM}" ];then
    REALM=${INSTANCE}
fi

function deploy() {
    UUID=`uuidgen`
    NOW=`date "+%Y%m%d_%H%M%S"`
    CODE_S3_PREFIX="${INSTANCE}/${NOW}/${UUID}"

    # Package sources and dependencies
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

    popd

    # Prepare upload bucket
    exist_s3_bucket ${CODE_UPLOAD_BUCKET} ${REGION} ${AWS_PROFILE} || create_s3_bucket ${CODE_UPLOAD_BUCKET} ${REGION} ${AWS_PROFILE}

    # Upload to s3 (code)
    run aws --region ${REGION} ${AWS_PROFILE_OPTION} s3 cp ${CODE_ZIP} s3://${CODE_UPLOAD_BUCKET}/${CODE_S3_PREFIX}/${CODE_ZIP}

    # deploy
    # When deleting getBucketName () in S3Util.js, also delete S3BucketNamePrefix.
    run aws --region ${REGION} ${AWS_PROFILE_OPTION} cloudformation deploy \
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
    S3BucketNamePrefix=${S3_BUCKET_NAME_PREFIX} \
    PythonRuntime=${DEFAULT_PYTHON_RUNTIME} \
    CloudFrontKeyPairID=${CLOUD_FRONT_KEY_PAIR_ID} \
    CloudFrontKeyPairBucket=${CLOUD_FRONT_KEY_PAIR_BUCKET} \
    CloudFrontKeyPairFileKey=${CLOUD_FRONT_KEY_PAIR_FILE_KEY}
}

# If IS_MASTER_DEPLOY is true, then confirmation will have been done in the main script.
# For CircleCI branches, deployment will be started immidiately
if ([ "${IS_MASTER_DEPLOY}" = "true" ] || [ -n "${CIRCLE_BRANCH}" ]); then
    deploy
else
    echo "Are you sure want to deploy instance $INSTANCE [Y/n]"
    read ANSWER

    case $ANSWER in
        "Y" | "y" | "yes" | "Yes" | "YES" )
            deploy
        ;;
        * )
            echo "Deploy operation cancelled"
            exit 0
        ;;
    esac
fi
