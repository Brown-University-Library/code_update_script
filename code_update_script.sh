#!/bin/bash


## define function for calls below
function reset_group_and_permissions () { 
  ## reset group and permissions
  declare -A path_array
  path_array["LOG_DIR_PATH"]="$LOG_DIR_PATH"
  path_array["PROJECT_DIR_PATH"]="$PROJECT_DIR_PATH"
  path_array["ENV_PATH"]="$ENV_PATH"

  for key in "${!path_array[@]}"; do
    p=${path_array[${key}]}
    if [[ -n $p ]]; then
      echo "processing directory:" "$p"
      sudo /bin/chgrp -R $GROUP "$p"  # recursively ensures all items are set to proper group -- solves problem of an item being root/root if sudo-updated after a forced deletion
      sudo /bin/chmod -R g=rwX "$p"
    else
      echo "Exiting - path not set:" "$key"
      exit
    fi

  done
  echo "---"; echo " "
}

## function to make a new venv and pip install the requirements file specified
function pip_deploy () {
  ## start in repo, because we need to get the commit hash
  cd "$PROJECT_DIR_PATH"
  ## construct venv name
  proj_name=${PROJECT_DIR_PATH%/} # removes trailing slash
  proj_name=${proj_name##*/} # grabs last string after slashes
  new_venv_name="venv_${proj_name}_$(date +%Y-%m-%d)_pip-deploy_$(git rev-parse --short HEAD)"

  cd ..
  ## make sure ./$new_venv_name doesn't already exist
  if [[ -d $new_venv_name ]]; then
    rm -rf $new_venv_name
  fi
  ## make new venv
  source ${ENV_PATH%/}/bin/activate || exit 1
  echo "Making new venv $new_venv_name with pip using $(python --version) from previous venv: $(readlink -f $ENV_PATH)"
  python -m venv $new_venv_name || exit 1
  deactivate

  ## install requirements
  source $new_venv_name/bin/activate || exit 1
  if [[ $(which pip) != $(pwd)/$new_venv_name/bin/pip ]]; then
    echo "using wrong pip ($(which pip))... exiting"
    exit 1
  fi
  pip install --ignore-installed --upgrade pip || exit 1
  # TODO: think about how to pass correct requirements file
  pip install --ignore-installed  -r $1 || exit 1

  echo;echo "running pip freeze:"
  pip freeze;echo

  ## relink env
  rm env
  ln -s $new_venv_name env
}

function uv_deploy () {
  cd "$PROJECT_DIR_PATH"
  ## construct venv name
  proj_name=${PROJECT_DIR_PATH%/} # removes trailing slash
  proj_name=${proj_name##*/} # grabs last string after slashes
  new_venv_name="venv_${proj_name}_$(date +%Y-%m-%d)_uv-deploy_$(git rev-parse --short HEAD)"

  cd ..
  ## make sure ./$new_venv_name doesn't already exist
  if [[ -d $new_venv_name ]]; then
    rm -rf $new_venv_name
  fi
  ## make new venv
  source ${ENV_PATH%/}/bin/activate || exit 1
  echo "Making new venv $new_venv_name with uv using $(python --version) from previous venv: $(readlink -f $ENV_PATH)"
  python_to_use=$(which python)
  uv venv $new_venv_name --python $python_to_use --native-tls --python-preference only-system --seed --relocatable || exit 1
  deactivate

  ## install requirements
  source $new_venv_name/bin/activate || exit 1
  if [[ $(which pip) != $(pwd)/$new_venv_name/bin/pip ]]; then
    echo "using wrong pip ($(which pip))... exiting"
    exit 1
  fi
  uv pip install --upgrade pip || exit 1
  # TODO: think about how to pass correct requirements file
  uv pip install -r $1 || exit 1

  echo;echo "running pip freeze:"
  pip freeze; echo

  ## relink env
  rm env
  ln -s $new_venv_name env
}

## parse arguments, exit early if incorrect
POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -permissions_only|--permissions_only)
      PERMISSIONS_ONLY=true
      shift
      if [[ $# -gt 0 ]]; then
        ## if extra args, exit early, do not reset group and permissions
        echo "Not updated. Can't use --permissions_only with other args"; echo
        exit 1
      fi
      ;;
    -pip_deploy|--pip_deploy)
      if [[ $2 == \-* ]]; then
        echo "Not updated. --pip-deploy needs a requirements-file argument"; echo
        exit 1
      fi
      PIP_DEPLOY_REQS="$2"
      DO_PIP_DEPLOY=true
      shift; shift # twice because this flag takes requirements as sub-arg
      if [[ $# -gt 0 ]]; then
        ## if extra args, exit early, do not make new venv
        echo "Not updated. Can't use --pip-deploy with other args"; echo
        exit 1
      fi
      ;;
    -uv_deploy|--uv_deploy)
      if [[ $2 == \-* ]]; then
        echo "Not updated. --uv-deploy needs a requirements-file argument"; echo
        exit 1
      fi
      UV_DEPLOY_REQS="$2"
      DO_UV_DEPLOY=true
      shift; shift # twice because this flag takes requirements as sub-arg
      if [[ $# -gt 0 ]]; then
        ## if extra args, exit early, do not make new venv
        echo "Not updated. Can't use --uv-deploy with other args"; echo
        exit 1
      fi
      ;;
    -h|--help)
      HELP_DESC="$0 does chmod, chgrp, git pull, and optionally collectstatic \
      and touch restart, based on envars"
      echo $HELP_DESC
      echo "Usage: $0 [flags]"
      HELP_FLAGS="\
        -(-)permissions_only=stop script after updating permissions and groups
        -(-)pip_deploy [requirements]=additionally make venv, install \
        requirements specified in [requirements], and symlink
        -h/--help=show this help and exit"
      column -ts "=" -W 2 <<< ${HELP_FLAGS//        /}
      exit
      ;;
    -*|--*)
      echo "unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

## reset group and permissions
echo "updating group and permissions..."; echo " "
reset_group_and_permissions

if [[ $PERMISSIONS_ONLY = true ]]; then
  echo "Exiting early because --permissions only was set"; echo
  exit
fi

echo "moving on to code update...."

## update app
echo "running git pull..."; echo " "
cd $PROJECT_DIR_PATH
git pull
echo "---"; echo " "

## make new venv
if [[ $DO_PIP_DEPLOY = true ]]; then
  echo "doing pip deploy..."
  pip_deploy $PIP_DEPLOY_REQS
elif [[ $DO_UV_DEPLOY = true ]]; then
  echo "doing uv deploy..."
  uv_deploy $UV_DEPLOY_REQS
fi

## run collectstatic if necessary (the `-n` test is for non-empty)
if [[ -n $PYTHON_PATH ]]; then
  echo "running collectstatic..."
  source $ACTIVATE_FILE
  $PYTHON_PATH ./manage.py collectstatic --noinput
  echo "---"; echo " "
fi

## reset group and permissions
echo "updating group and permissions after code-update..."; echo " "
reset_group_and_permissions

## make it real
echo "touching the restart file..."
touch $TOUCH_PATH
sleep 1
echo "---"; echo " "

if [[ -n $URLS_TO_CHECK ]]; then
    echo "running curl-check..."
    for url in "${URLS_TO_CHECK[@]}"
    do
    echo " "; echo "checking url: " $url
    RESPONSE=$( curl --head  --silent --max-time 3 $url )
    #echo "$RESPONSE"
    if [[ $RESPONSE == *"HTTP/1.1 200 OK"* ]]; then
        echo "curl-check: good!"
    else
        echo "curl-check: no 200?"
    fi
    done
else
    echo "no urls to curl..."
fi
    
echo "---"; echo " "

echo "DEPLOY-COMPLETE"; echo " "; echo "--------------------"; echo " "

## [END]
