Simple script to check public key fingerprints against a database for expairy dates. It assumes mysql but should be simple enough to port.
Takes the inputs from the AuthorizedKeysCommand command and returns the public key if it is allowed and 1 if it is not. 


Install

In sshd_config.conf add the following:

PubkeyAuthentication yes
AuthorizedKeysFile /dev/null
AuthorizedKeysCommand /usr/bin/validate_keys %u %h %k %f %t
AuthorizedKeysCommandUser %u

This runs as the user to ensure access to home directory for root squashed filesystems. Alternatively it can be run as root. Check permissions needed for your system.


