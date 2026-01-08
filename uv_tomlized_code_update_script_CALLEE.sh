#!/bin/bash

## assumes `uv` is installed and available in PATH

## Usage: `bash ./CALLER.sh`, which sets vars and then runs `source /path/to/CALLEE.sh`

## helper code ------------------------------------------------------

## function for calls below
function reset_group_and_permissions () { 
    if [[ -n $STATIC_WEB_DIR_PATH ]]; then
        path_array=( $LOG_DIR_PATH $STUFF_DIR_PATH $STATIC_WEB_DIR_PATH )
    else
        path_array=( $LOG_DIR_PATH $STUFF_DIR_PATH )
    fi
    for dir_path in "${path_array[@]}"
    do
        echo "processing directory: " $dir_path
        sudo /bin/chgrp -R $GROUP $dir_path  
        sudo /bin/chmod -R g=rwX $dir_path
        ## ensure group inheritance for newly-created files/dirs under this tree
        find "$dir_path" -type d -exec sudo /bin/chmod g+s {} +
    done
}

## main code --------------------------------------------------------

## reset INITIAL group and permissions ----------
echo ":: running INITIAL group and permissions update..."; echo " "
reset_group_and_permissions
echo "---"; echo " "; echo " "

## update app -----------------------------------
echo ":: running git pull..."; echo " "
cd $PROJECT_DIR_PATH
git pull
echo "---"; echo " "; echo " "

## update any python packages -------------------
echo "running uv sync..."; echo " "
uv sync --locked --group $UV_GROUP
echo "---"; echo " "; echo " "

## run collectstatic ----------------------------
if [[ -n $STATIC_WEB_DIR_PATH ]]; then
    echo "running collectstatic..."
    uv run ./manage.py collectstatic --noinput
    echo "---"; echo " "; echo " "
fi

## reset FINAL group and permissions -----------
echo "running final ownership and permissions update..."; echo " "
reset_group_and_permissions
echo "---"; echo " "; echo " "

## make it real
if [[ -n $TOUCH_PATH ]]; then   
    echo "touching the restart file..."
    touch $TOUCH_PATH
    sleep 1
    echo "---"; echo " "; echo " "
fi

## run tests ------------------------------------
echo ":: running tests..."; echo " "
cd $PROJECT_DIR_PATH
if uv run ./run_tests.py; then
    echo "Tests passed successfully"
else
    echo "ERROR: Tests failed with exit code $?"
    echo "Please check the test output above for details"
    echo "Continuing with deployment despite test failure..."
fi
echo "---"; echo " "; echo " "

## check urls -----------------------------------
if [[ -n $URLS_TO_CHECK ]]; then
    echo "running curl-check..."
    for url in "${URLS_TO_CHECK[@]}"
    do
        echo " "; echo "checking url: " $url
        HTTP_CODE=$(curl --head -s -o /dev/null -w "%{http_code}" --max-time 5 $url)
        if [[ $HTTP_CODE == "200" ]]; then
            echo "curl-check: good! (HTTP $HTTP_CODE)"
        else
            echo "curl-check: FAILED - received HTTP $HTTP_CODE (expected 200)"
        fi
    done
else
    echo "no urls to curl..."
fi
    
echo "---"; echo " "; echo " "

## that's it! -----------------------------------
echo "DEPLOY-COMPLETE"; echo " "; echo "--------------------"; echo " "

## [END]
