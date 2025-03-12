# Purpose

To standardize code-update deploys.

---

# Usage

does chmod, chgrp, git pull, and optionally collectstatic and touch restart, based on envars in a caller script
```
-(-)permissions_only           stop script after updating permissions and groups
-(-)pip_deploy [requirements]  additionally make venv, install requirements specified in [requirements], and set symlink
-h/--help                      show this help and exit"
```
    
