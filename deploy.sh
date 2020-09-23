#!/bin/bash

dir_error() {
    echo "Cloud API deploy script must be executed from the project root directory."
    exit 1
}

echo $AWS_ACCESS_KEY_ID
usage() {
    cat <<_EOT_
Decription:
  Deploy the cloud-aws platform.
Usage:
    $0
    --parameter-local-file-path <value>
    [--aws-profile <value>]
    [--with-events]
    [--help]

Options:
    --parameter-local-file-path (string)
        The path of the parameter local file.

    --aws-profile (string: optional)
        AWS CLI profile name
        default: none

    --with-events (boolean: optional)
        If present, also deploy the Scorer console UI stack.

    --help
        Show usage.
_EOT_
    exit 1
}


PARAMETER_LOCAL_FILE_PATH=""
AWS_PROFILE=""
EVENTS_DEPLOY_FLAG=false

echo "$1"

while true; do
    case "$1" in
        --aws-profile ) validate_argument $2; AWS_PROFILE=$2; shift 2 ;;
        --with-events ) EVENTS_DEPLOY_FLAG=true; shift ;;
        --help ) usage; shift ;;
        -* | --* ) usage; shift; break ;;
        * ) shift; break ;;
    esac
done

fun1(){
  echo "Printing fun1"
}

fun1

if [ -n "${AWS_PROFILE}" ]; then
    AWS_PROFILE_OPTION="--aws-profile ${AWS_PROFILE}"
fi

echo "${AWS_PROFILE_OPTION}"
deploy() {
    export IS_MASTER_DEPLOY=true
    if "${EVENTS_DEPLOY_FLAG}"; then
        echo "calling deploy"
        pushd ./events/cloudformation
        ./deploy.sh ${AWS_PROFILE_OPTION}
        if [ $? -ne 0 ]; then
            exit 1
        fi
        popd
    fi

    unset IS_MASTER_DEPLOY
    echo "DEPLOYMENT DONE!"
}
deploy
