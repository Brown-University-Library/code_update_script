#!/bin/bash

## assumes `uv` is installed and available in PATH

## Usage: `bash ./CALLER.sh`, which sets vars and then runs `source /path/to/CALLEE.sh`
## Usage with flag: `bash ./CALLER.sh --permissions-only` to only reset permissions

function show_help () {
    HELP_DESC="$0 resets group/perms, pulls the repo, syncs uv dependencies, auto-runs collectstatic if necessary, re-applies final perms, touches the restart file if necessary, runs tests on non-prod, and curl-checks any configured URLs"
    echo "$HELP_DESC"
    echo "Usage: $0 [flags]"
    printf '%-32s %s\n' \
      '--permissions-only' 'stop script after updating permissions and groups' \
      '-h/--help' 'show this help and exit'
}

## parse possible arguments -----------------------------------------
PERMISSIONS_ONLY=false
while [[ $# -gt 0 ]]; do
  case $1 in
    --permissions-only)
      PERMISSIONS_ONLY=true
      shift
      ;;
    -h|--help)
      show_help
      return 0
      ;;
    -*|--*)
      echo "unknown option $1"; echo " "
      show_help
      return 1
      ;;
    *)
      shift
      ;;
  esac
done

## helper code ------------------------------------------------------

## function for calls below
function reset_group_and_permissions () { 
    if [[ -n $STATIC_WEB_DIR_PATH ]]; then
        path_array=( "$LOG_DIR_PATH" "$STUFF_DIR_PATH" "$STATIC_WEB_DIR_PATH" )
    else
        path_array=( "$LOG_DIR_PATH" "$STUFF_DIR_PATH" )
    fi
    for dir_path in "${path_array[@]}"
    do
        echo "processing directory: $dir_path"
        sudo /bin/chgrp -R "$GROUP" "$dir_path"
        sudo /bin/chmod -R g=rwX "$dir_path"
    done
    ## ensure group inheritance for newly-created files/dirs under this tree
    find "$PROJECT_DIR_PATH" -type d -exec sudo /bin/chmod g+s {} +
    ## ensure read-write permissions for the specified group for newly-created files/dirs under this tree
    # find "$PROJECT_DIR_PATH" -type d -exec sudo setfacl -m d:g:"$GROUP":rwX,d:m::rwX {} +
}

## main code --------------------------------------------------------

## reset INITIAL group and permissions ----------
echo ":: running INITIAL group and permissions update..."; echo " "
reset_group_and_permissions
echo "---"; echo " "; echo " "

## exit early if only permissions update was requested
if [[ $PERMISSIONS_ONLY = true ]]; then
    echo ":: Exiting early because --permissions-only was set"; echo " "
    echo "PERMISSIONS-ONLY-UPDATE COMPLETE"; echo " "; echo "--------------------"; echo " "
    return 0  # use 'return' instead of 'exit' since this script is sourced
fi

## update app -----------------------------------
echo ":: running git pull..."; echo " "
cd "$PROJECT_DIR_PATH"
git pull
echo "---"; echo " "; echo " "

## update any python packages -------------------
echo ":: running uv sync..."; echo " "
uv sync --locked --group $UV_GROUP
echo "---"; echo " "; echo " "

## run collectstatic ----------------------------
if [[ -n $STATIC_WEB_DIR_PATH ]]; then
    echo ":: running collectstatic..."; echo " "
    uv run ./manage.py collectstatic --noinput
    echo "---"; echo " "; echo " "
fi

## reset FINAL group and permissions -----------
echo ":: running final ownership and permissions update..."; echo " "
reset_group_and_permissions
echo "---"; echo " "; echo " "

## make it real
if [[ -n $TOUCH_PATH ]]; then   
    echo ":: touching the restart file..."; echo " "
    touch "$TOUCH_PATH"
    sleep 1
    echo "ok"
    echo "---"; echo " "; echo " "
fi

## run tests if not production ------------------
HOSTNAME=$(hostname)
if [[ ! $HOSTNAME =~ ^p.* ]]; then
    echo ":: running tests (non-production server: $HOSTNAME)..."; echo " "
    cd "$PROJECT_DIR_PATH"
    if test_output=$(uv run ./run_tests.py 2>&1); then
        echo "Tests passed successfully"
    else
        echo "ERROR: Tests failed with exit code $?"
        echo "$test_output"
        echo "Continuing with deployment despite test failure..."
    fi
    echo "---"; echo " "; echo " "
else
    echo ":: skipping tests (production server: $HOSTNAME)"; echo " "
    echo "---"; echo " "; echo " "
fi

## check urls -----------------------------------
if [[ -n $URLS_TO_CHECK ]]; then
    echo ":: running curl-check..."
    for url in "${URLS_TO_CHECK[@]}"
    do
        echo " "; echo "checking url: $url"
        HTTP_CODE=$(curl --head -s -o /dev/null -w "%{http_code}" --max-time 5 "$url")
        if [[ $HTTP_CODE == "200" ]]; then
            echo "curl-check: good! (HTTP $HTTP_CODE)"
        else
            echo "curl-check: FAILED - received HTTP $HTTP_CODE (expected 200)"
        fi
    done
    echo "---"; echo " "; echo " "
fi

## that's it! -----------------------------------
echo "DEPLOY-COMPLETE"; echo " "; echo "--------------------"; echo " "

## [END]
