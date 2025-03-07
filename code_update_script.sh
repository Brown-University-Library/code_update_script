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

## look for "--permissions_only" argument 
if [[ $1 =~ -permissions_only|--permissions_only ]]; then
  ## reset group and permissions
  reset_group_and_permissions
  echo "Remember, this only sets group and permissions."; echo
  exit
elif [[ $# -ge 1 ]]; then
  echo "Exiting -- only permissible argument: --permissions_only"; echo
  exit
fi

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
