# Purpose

To standardize code-update deploys.

---


# Usage

Note that the "callee" scripts in this repository are not called directly. Instead -- the last line of the "caller" script should be:

```
source /path/to/the_CALLEE.sh
```

## `uv_tomlized_code_update_script_CALLEE.sh` 

This is the script to call for the newer projects that **do** have a `pyproject.toml` file. 

Features:
- updates permissions and groups before and after the deploy
- runs `git pull`
- runs `uv sync --locked --group $UV_GROUP`
- auto-runs django's `collectstatic` if `STATIC_WEB_DIR_PATH` is set
- touches the restart file if `TOUCH_PATH` is set
- ensures newly created files and directories under `PROJECT_DIR_PATH` keep inheriting the expected group
- runs tests after the update on non-production hosts, and logs failures without aborting the deploy
- curl-checks configured URLs if `URLS_TO_CHECK` is set
- optionally runs in `--permissions-only` mode

Usage:
```
$ bash ./specific_project_caller.sh
```

or

```
$ bash ./specific_project_caller.sh --permissions-only
```

or

```
$ bash ./specific_project_caller.sh --help
```

---


## `code_update_script.sh` 

This is a script to call for the older projects that do **not** have a `pyproject.toml` file.

does chmod, chgrp, git pull, and optionally collectstatic and touch restart, based on envars in a caller script

```
-(-)permissions_only           stop script after updating permissions and groups
-(-)pip_deploy [requirements]  additionally make venv, install requirements specified in [requirements], and set symlink
-h/--help                      show this help and exit"
```

---


## `code_update_script_NEW.sh` 

This is a script to call for the older projects that do **not** have a `pyproject.toml` file that offers more capabilities.

Note that it has not been extensively tested. If you use it successfully, let the team know.

`code_update_script_NEW.sh` (callee): resets group/perms on key paths, `git pull`s the repo, optionally creates/symlinks a new venv via `--pip_deploy <requirements.txt>` or `--uv_deploy <requirements.txt>`, optionally runs `collectstatic`, then touches the restart file (run it by `source`ing it from a per-project caller script after setting the required envars).

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

For `uv_tomlized_code_update_script_CALLEE.sh`, these envars control significant behavior:

- `PROJECT_DIR_PATH`: directory the script `cd`s into before `git pull`, `uv sync`, and test execution
- `LOG_DIR_PATH` and `STUFF_DIR_PATH`: always included in the permissions/group reset
- `STATIC_WEB_DIR_PATH`: if set, included in the permissions/group reset and triggers `uv run ./manage.py collectstatic --noinput`
- `GROUP`: group applied by `chgrp -R`
- `UV_GROUP`: dependency group passed to `uv sync --locked --group`
- `TOUCH_PATH`: if set, the script touches this file near the end of the deploy
- `URLS_TO_CHECK`: if set, the script runs a `curl --head` check against each configured URL

## tests

In the `uv_tomlized_code_update_script_CALLEE.sh` script, tests are auto-run on non-production servers, but skipped on production hosts whose hostname begins with `p`, to minimize the chance that a test may write to the production database in an unintended way.

On a successful test-run, the script output will simply indicate that the tests were successful. On any failures, the full test-output logging will be shown, but the deploy will continue.

## permissions

The command below: 
```
## ensure group inheritance for newly-created files/dirs under this tree
find "$dir_path" -type d -exec sudo /bin/chmod g+s {} +
```

...was removed from the `uv_tomlized_code_update_script_CALLEE.sh` script -- in the permissions-update-for-loop -- because it could generate a "too many arguments" error on some stuff-directories with lots of subdirectories. 

It was moved to the bottom of that function, scoped to the project-directory.

This line is important, because without it -- even after running the code-update script, `__pycache__` files can be created with non-group-writable permissions. If the auto-updater perceives any files in the project-directory that are not group-writable, it won't run. This command addresses that.

---
