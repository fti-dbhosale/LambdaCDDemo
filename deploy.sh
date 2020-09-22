#!/bin/bash

dir_error() {
    echo "Scorer Cloud API deploy script must be executed from the project root directory."
    exit 1
}

usage() {
    cat <<_EOT_
Decription:
  Deploy the scorer-cloud-aws platform.
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

if true; then
  echo 'test'
    case "$1" in

        --parameter-local-file-path ) validate_argument $2; PARAMETER_LOCAL_FILE_PATH=$2; shift 2 ;;
        --aws-profile ) validate_argument $2; AWS_PROFILE=$2; shift 2 ;;
        --with-events ) EVENTS_DEPLOY_FLAG=true; shift ;;
        --help ) usage; shift ;;

    esac
fi

if [ -z "${PARAMETER_LOCAL_FILE_PATH}" ]; then
    usage
fi

PARAMETER_FILE_ABSOLUTE_PATH=$(pwd)/$(dirname ${PARAMETER_LOCAL_FILE_PATH})/$(basename ${PARAMETER_LOCAL_FILE_PATH})

if [ -n "${AWS_PROFILE}" ]; then
    AWS_PROFILE_OPTION="--aws-profile ${AWS_PROFILE}"
fi

JSON_PARAMS_FILE=`create_parameter_file ${PARAMETER_FILE_ABSOLUTE_PATH}`

deploy() {
    export IS_MASTER_DEPLOY=true

    if "${LOG_STORE_DEPLOY_FLAG}"; then

        pushd ./log-store
        ./deploy.sh ${AWS_PROFILE_OPTION} --parameter-local-file-path ${PARAMETER_FILE_ABSOLUTE_PATH}
        if [ $? -ne 0 ]; then
            exit 1
        fi
        popd
    fi

    if "${EVENTS_DEPLOY_FLAG}"; then
        echo 'test1'
        pushd ./events/cloudformation
        ./deploy.sh ${AWS_PROFILE_OPTION} --parameter-local-file-path ${PARAMETER_FILE_ABSOLUTE_PATH}
        if [ $? -ne 0 ]; then
            exit 1
        fi
        popd
    fi

    unset IS_MASTER_DEPLOY
    echo "DEPLOYMENT DONE!"
}

run_integration_tests() {
    echo "Running integration tests ..."
    pushd ./scorer_api
    # need to reinstall and rebuild because deployment process prunes dev dependencies
    npm install && npm run build
    # don't rely on the preintegration hook to do this for us (maybe fixable if we configure npm to use bash as the script-shell)
    pushd ./integration_test/scripts
    ./generate-config.sh
    popd
    # same as npm run integration, except wont run the pre-hook
    npm run integration:container
    popd
}

readonly REALM_PARAM_KEY="RealmName"
readonly INSTANCE_PARAM_KEY="InstanceName"
readonly REGION_PARAM_KEY="AWSRegion"
readonly API_VERSION_PARAM_KEY="ScorerApiVersion"
readonly STORAGE_EVENT_FUNCTION_VERSION_PARAM_KEY="StorageEventFunctionVersion"
readonly CLUSTER_EVENT_FUNCTION_VERSION_PARAM_KEY="ClusterEventFunctionVersion"
readonly AUTHENTICATION_EVENT_FUNCTION_VERSION_PARAM_KEY="AuthenticationEventFunctionVersion"
readonly ADMIN_FUNCTION_VERSION_PARAM_KEY="ScorerAdminFunctionVersion"
readonly PUBLIC_API_VERSION_PARAM_KEY="PublicApi.VersionPrefix"

REALM=`get_parameter ${JSON_PARAMS_FILE} ${REALM_PARAM_KEY}`

if ([ ${REALM} = "dev" ] || [ -n "$CIRCLE_BRANCH" ]); then
    # For dev and CircleCI branches, deployment will be started immidiately
    echo "${REALM_PARAM_KEY}: ${REALM}"
    cleanUp ${JSON_PARAMS_FILE}
    deploy
    # no need to run on CircleCI because a later step will run them
    if [ -z "${CIRCLE_BRANCH}" ]; then
        run_integration_tests
    fi
else
    INSTANCE=`get_parameter ${JSON_PARAMS_FILE} ${INSTANCE_PARAM_KEY}`
    REGION=`get_parameter ${JSON_PARAMS_FILE} ${REGION_PARAM_KEY}`
    API_VERSION=`get_parameter ${JSON_PARAMS_FILE} ${API_VERSION_PARAM_KEY}`
    STORAGE_EVENT_FUNCTION_VERSION=`get_parameter ${JSON_PARAMS_FILE} ${STORAGE_EVENT_FUNCTION_VERSION_PARAM_KEY}`
    CLUSTER_EVENT_FUNCTION_VERSION=`get_parameter ${JSON_PARAMS_FILE} ${CLUSTER_EVENT_FUNCTION_VERSION_PARAM_KEY}`
    AUTHENTICATION_EVENT_FUNCTION_VERSION=`get_parameter ${JSON_PARAMS_FILE} ${AUTHENTICATION_EVENT_FUNCTION_VERSION_PARAM_KEY}`
    ADMIN_FUNCTION_VERSION=`get_parameter ${JSON_PARAMS_FILE} ${ADMIN_FUNCTION_VERSION_PARAM_KEY}`
    PUBLIC_API_VERSION=`get_parameter ${JSON_PARAMS_FILE} ${PUBLIC_API_VERSION_PARAM_KEY}`
    cleanUp ${JSON_PARAMS_FILE}

    echo "Please confirm the details for this deployment:"
    echo "${REALM_PARAM_KEY}: ${REALM}"
    echo "${INSTANCE_PARAM_KEY}: ${INSTANCE}"
    echo "${REGION_PARAM_KEY}: ${REGION}"
    echo "${API_VERSION_PARAM_KEY}: ${API_VERSION}"
    echo "${STORAGE_EVENT_FUNCTION_VERSION_PARAM_KEY}: ${STORAGE_EVENT_FUNCTION_VERSION}"
    echo "${CLUSTER_EVENT_FUNCTION_VERSION_PARAM_KEY}: ${CLUSTER_EVENT_FUNCTION_VERSION}"
    echo "${AUTHENTICATION_EVENT_FUNCTION_VERSION_PARAM_KEY}: ${AUTHENTICATION_EVENT_FUNCTION_VERSION}"
    echo "${ADMIN_FUNCTION_VERSION_PARAM_KEY}: ${ADMIN_FUNCTION_VERSION}"
    echo "${PUBLIC_API_VERSION_PARAM_KEY}: ${PUBLIC_API_VERSION}"
    echo
    echo "Are you sure you want to deploy realm $REALM [Y/n]"
    read ANSWER

    case $ANSWER in
        "" | "Y" | "y" | "yes" | "Yes" | "YES" )
            echo "Please type a realm name what you want to deploy. $REALM"
            read TYPED_REALM

            if [[ ${TYPED_REALM} == ${REALM} ]]; then

                echo "Deployment started ..."
                deploy
                run_integration_tests

            else
                echo "The realm name that you typed is not matched with realm $REALM"
                exit 1
            fi
        ;;
        * )
            echo "Deploy operation cancelled"
            exit 0
        ;;
    esac
fi
