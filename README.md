# Magicnt

> Run something in a container

Here a collection of helper functions for bash:

* Set up the container with `magicnt_activate` (hint: there is a shortcut for Python: `magicnt_python`).
* You could already have some commands aliased to the container (for instance `python` in the Python shortcut), or you can run commands with `in_container [sudo] ...`. The working directory is synchronized.
* Use `magicnt_deactivate` to destroy everything.

All function respond to the `-h` parameter with further information.
