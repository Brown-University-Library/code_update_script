# Purpose

To standardize code-update deploys.

---

# Usage

Note that the "callee" scripts in this repository are not called directly. Instead -- the last line of the "caller" script should be:

```
source /path/to/CALLEE.sh
```

## `code_update_script.sh` usage

This is the script to call for the older projects that do **not** have a `pyproject.toml` file.

does chmod, chgrp, git pull, and optionally collectstatic and touch restart, based on envars in a caller script

```
-(-)permissions_only           stop script after updating permissions and groups
-(-)pip_deploy [requirements]  additionally make venv, install requirements specified in [requirements], and set symlink
-h/--help                      show this help and exit"
```
    
## `uv_tomlized_code_update_script_CALLEE.sh` usage

This is the script to call for the newer projects that **do** have a `pyproject.toml` file.

```
$ bash ./specific_project_caller.sh
```

or

```
$ bash ./specific_project_caller.sh --permissions_only
```

---

# Notes

## envars

Most of the envars in a caller script are set using the format:

```
VAR_NAME="var_value"
```

However, the `uv_tomlized_code_update_script_CALLEE.sh` script accepts an optional $URLS_TO_CHECK variable, which should be set using the format:

```
URLS_TO_CHECK=(
    "https://url_1"
    "https://url_2"
)
```

## tests

Tests are auto-run on dev-servers, but not on prod-servers, to minimize the chance that a test may write to the production database in an unintended way.

On a successful test-run, the script output will simply indicate that the tests were successful. On any failures, the full test-output logging will be shown.

---
