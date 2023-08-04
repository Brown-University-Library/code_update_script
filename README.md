# Purpose

To standardize code-update deploys.

---

# Usage

- cd into the code_update_script_stuff directory

- if necessary, create a project_code_update_caller.sh script, specifying the variables required in `code_update_script.sh`. Example:

    ```bash
    #!/bin/sh

    ## set envars -------------------------------------------------------
    echo " "; echo "--------------------"; echo " "; echo "DEPLOY-START"; echo " "
    echo "setting envars..."
    LOG_DIR_PATH="/path/to/log_dir
    (etc)
    echo "---"; echo " "

    ## call this code_update_script.sh ----------------------------------
    source /path/to/this/code_update_script.sh
    ```

- run the code-caller.sh script. Example:

    ```bash
    bash ./project_code_update_caller.sh
    ```
    