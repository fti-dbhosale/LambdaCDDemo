#!/bin/bash

function dir_error() {
    echo "Please execute on the directory where the script is located."
    exit 1
}
readonly SCRIPT_MODULE_DIR="../../"
. ${SCRIPT_MODULE_DIR}script-module/scorer-util.sh || dir_error


function usage() {
    cat <<_EOT_
Usage:
    $0
    [--parameter-file-url <value>]
    [--parameter-local-file-path <value>]
    [--aws-profile <value>]
    [--help]
Options:
    --parameter-file-url (string)
        The URL of the parameter file.
        Required if "--parameter-local-file-path" is not set.
    --parameter-local-file-path (string)
        The path of the parameter local file.
        If this option is specified, "--parameter-file-url" is ignored.
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


function validate_arguments() {
    if [ -n "${PARAMETER_LOCAL_FILE_PATH}" ]; then
        return
    fi

    if [ -z "${PARAMETER_FILE_URL}" ]; then
        usage
    fi
}

readonly INSTANCE_PARAM_KEY="InstanceName"
readonly REALM_PARAM_KEY="RealmName"
readonly REGION_PARAM_KEY="AWSRegion"
readonly LAMBDA_VERSION_PARAM_KEY="EventsFunctionVersion"
readonly CODE_UPLOAD_BUCKET_PARAM_KEY="CodeUploadBucket"
readonly DEFAULT_PYTHON_RUNTIME_PARAM_KEY="Lambda.DefaultPythonRuntime"
# TODO
# When deleting getBucketName () in S3Util.js, delete this line as well.
readonly S3_BUCKET_NAME_PREFIX_PARAM_KEY="S3BucketNamePrefix"
readonly CLOUD_FRONT_KEY_PAIR_ID_PARAM_KEY="CloudFrontKeyPair.ID"
readonly CLOUD_FRONT_KEY_PAIR_FILE_KEY_PARAM_KEY="CloudFrontKeyPair.FileKey"
readonly CLOUD_FRONT_KEY_PAIR_BUCKET_PARAM_KEY="CloudFrontKeyPair.Bucket"

function parameter_error() {
    echo "Parameter error: ${1}"
}

function validate_parameters() {
    local is_error=false
    if [ -z "$CODE_UPLOAD_BUCKET" ]; then
        parameter_error ${CODE_UPLOAD_BUCKET_PARAM_KEY}
        is_error=true
    fi
    if [ -z "${CLOUD_FRONT_KEY_PAIR_ID}" ]; then
      parameter_error ${CLOUD_FRONT_KEY_PAIR_ID_PARAM_KEY}
      is_error=true
    fi

    if [ -z "${CLOUD_FRONT_KEY_PAIR_BUCKET}" ]; then
        parameter_error ${CLOUD_FRONT_KEY_PAIR_BUCKET_PARAM_KEY}
        is_error=true
    fi

    if [ -z "${CLOUD_FRONT_KEY_PAIR_FILE_KEY}" ]; then
        parameter_error ${CLOUD_FRONT_KEY_PAIR_FILE_KEY_PARAM_KEY}
        is_error=true
    fi
    # TODO
    # When deleting getBucketName () in S3Util.js, delete this line as well.

    if [ -z "$S3_BUCKET_NAME_PREFIX" ]; then
        parameter_error ${S3_BUCKET_NAME_PREFIX_PARAM_KEY}
        is_error=true
    fi

    if [ -z "$INSTANCE" ]; then
        parameter_error ${INSTANCE_PARAM_KEY}
        is_error=true
    fi

    if [ -z "$REGION" ]; then
        parameter_error ${REGION_PARAM_KEY}
        is_error=true
    fi

    if [ -z "${LAMBDA_VERSION}" ]; then
        parameter_error ${LAMBDA_VERSION_PARAM_KEY}
        is_error=true
    fi

    # Regex validation for api version
    if [[ ! ${LAMBDA_VERSION} =~ ^([0-9]+)-([0-9]+)$ ]]; then
        parameter_error "${LAMBDA_VERSION_PARAM_KEY} validation failed"
        is_error=true
    fi

    if [ -z "${DEFAULT_PYTHON_RUNTIME}" ]; then
        parameter_error ${DEFAULT_PYTHON_RUNTIME_PARAM_KEY}
        is_error=true
    fi

    if "${is_error}"; then
        exit 1
    fi
}


PARAMETER_FILE_URL=""
PARAMETER_LOCAL_FILE_PATH=""
AWS_PROFILE=""
DEFAULT_PYTHON_RUNTIME=""

while true; do
    case "$1" in
        --parameter-file-url ) validate_argument $2; PARAMETER_FILE_URL=$2; shift 2 ;;
        --parameter-local-file-path ) validate_argument $2; PARAMETER_LOCAL_FILE_PATH=$2; shift 2 ;;
        --aws-profile ) validate_argument $2; AWS_PROFILE=$2; shift 2 ;;
        --help ) usage; shift ;;
        -* | --* ) usage; shift; break ;;
        * ) shift; break ;;
    esac
done

# Args validation
validate_arguments

# Dependencies validation
validate_dependencies

# Get parameter
if [ -n "${PARAMETER_LOCAL_FILE_PATH}" ]; then
    JSON_PARAMS_FILE=`create_parameter_file ${PARAMETER_LOCAL_FILE_PATH} ${SCRIPT_MODULE_DIR}`
else
    JSON_PARAMS_FILE=`create_parameter_file_by_url ${PARAMETER_FILE_URL} ${SCRIPT_MODULE_DIR}`
fi
CODE_UPLOAD_BUCKET=`get_parameter ${JSON_PARAMS_FILE} ${CODE_UPLOAD_BUCKET_PARAM_KEY}`
INSTANCE=`get_parameter ${JSON_PARAMS_FILE} ${INSTANCE_PARAM_KEY}`
REALM=`get_parameter ${JSON_PARAMS_FILE} ${REALM_PARAM_KEY}`
REGION=`get_parameter ${JSON_PARAMS_FILE} ${REGION_PARAM_KEY}`
LAMBDA_VERSION=`get_parameter ${JSON_PARAMS_FILE} ${LAMBDA_VERSION_PARAM_KEY}`
STACK_NAME=event-function-$INSTANCE-$LAMBDA_VERSION
DEFAULT_PYTHON_RUNTIME=`get_parameter ${JSON_PARAMS_FILE} ${DEFAULT_PYTHON_RUNTIME_PARAM_KEY}`
CLOUD_FRONT_KEY_PAIR_ID=`get_parameter ${JSON_PARAMS_FILE} ${CLOUD_FRONT_KEY_PAIR_ID_PARAM_KEY}`
CLOUD_FRONT_KEY_PAIR_BUCKET=`get_parameter ${JSON_PARAMS_FILE} ${CLOUD_FRONT_KEY_PAIR_BUCKET_PARAM_KEY}`
CLOUD_FRONT_KEY_PAIR_FILE_KEY=`get_parameter ${JSON_PARAMS_FILE} ${CLOUD_FRONT_KEY_PAIR_FILE_KEY_PARAM_KEY}`
# TODO
# When deleting getBucketName () in S3Util.js, delete this line as well.
S3_BUCKET_NAME_PREFIX=`get_parameter ${JSON_PARAMS_FILE} ${S3_BUCKET_NAME_PREFIX_PARAM_KEY}`

# Crean up
rm -fr ${JSON_PARAMS_FILE}

# Parameter validation
validate_parameters

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
