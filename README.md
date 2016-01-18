# CNTLM
This script will help setup NTLM on Ubuntu using CNTLM.

Currently this has only been tested on Ubuntu.

The script has the following features:

- Checks if CNTLM is installed.
- Verifies that the credentials and proxy are valid before they are applied.
- Applies the proxy system wide by default.
    - Note this can be disabled by removing the entries from /etc/environment.
- Asks if the proxy settings are to be applied globally.
- Provides an option to disable logging of all websites visited in syslog which is enabled by default in CNTLM!