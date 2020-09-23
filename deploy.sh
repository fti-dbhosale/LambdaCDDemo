dir_error() {
    echo "Cloud API deploy script must be executed from the project root directory."
    exit 1
}

PARAMETER_LOCAL_FILE_PATH=""
AWS_PROFILE=""
EVENTS_DEPLOY_FLAG=false

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
