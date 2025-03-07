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
  proj_name=${PROJECT_DIR_PATH%/} # grabs last string after slashes
  proj_name=${proj_name##*/}
  new_venv_name="venv_${proj_name}_$(date +%Y-%m-%d)_pip-deploy_$(git rev-parse --short HEAD)"

  cd ..
  ## make sure ./$new_venv_name doesn't already exist
  rm -rf $new_venv_name
  ## make new venv
  source $ENV_PATH/bin/activate
  echo "Making new venv $new_venv_name with pip using $(python --version) from previous venv: $(readlink -f $ENV_PATH)"
  python -m venv $new_venv_name
  deactivate

  ## install requirements
  source $new_venv_name/bin/activate
  if [[ $(which pip) != $(pwd)/$new_venv_name/bin/pip ]]; then
    echo "using wrong pip ($(which pip))... exiting"
    exit 1
  fi
  pip install --ignore-installed --upgrade pip
  # TODO: think about how to pass correct requirements file
  pip install --ignore-installed  -r $1

  echo;echo "running pip freeze:"
  pip freeze;echo

  ## relink env
  rm env
  ln -s $new_venv_name env
}

function uv_deploy () {
  cd "$PROJECT_DIR_PATH"
  ## construct venv name
  proj_name=${PROJECT_DIR_PATH%/} # grabs last string after slashes
  proj_name=${proj_name##*/}
  new_venv_name="venv_${proj_name}_$(date +%Y-%m-%d)_uv-deploy_$(git rev-parse --short HEAD)"

  cd ..
  ## make new venv
  source $ENV_PATH/bin/activate
  echo "Making new venv $new_venv_name with uv using $(python --version) from previous venv: $(readlink -f $ENV_PATH)"
  python_to_use=$(which python)
  uv venv $new_venv_name --python $python_to_use --native-tls --python-preference only-system --seed --relocatable
  deactivate

  ## install requirements
  source $new_venv_name/bin/activate
  if [[ $(which pip) != $(pwd)/$new_venv_name/bin/pip ]]; then
    echo "using wrong pip ($(which pip))... exiting"
    exit 1
  fi
  uv pip install --upgrade pip
  # TODO: think about how to pass correct requirements file
  uv pip install -r $1

  echo;echo "running pip freeze:"
  pip freeze

  ## relink env
  rm env
  ln -s $new_venv_name env
}

## reset group and permissions
echo "updating group and permissions before code-update..."; echo " "
reset_group_and_permissions

## update app
echo "running git pull..."; echo " "
cd $PROJECT_DIR_PATH
git pull
echo "---"; echo " "

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
