Simple script to check public key fingerprints against a database for expairy dates. It assumes mysql but should be simple enough to port.
Takes the inputs from the AuthorizedKeysCommand command and returns the public key if it is allowed and 1 if it is not. 


Install

mysql/mariadb

For RHEL 7 and later mysql server has been replaced by Mariadb

yum install mariadb-server
systemctl enable --now  mariadb

The database needs a table called public_keys with the following description

+-------------+-------------+------+-----+---------+-------+
| Field       | Type        | Null | Key | Default | Extra |
+-------------+-------------+------+-----+---------+-------+
| username    | varchar(10) | NO   |     | NULL    |       |
| fingerprint | varchar(50) | NO   | PRI | NULL    |       |
| cutoff_date | date        | NO   |     | NULL    |       |
+-------------+-------------+------+-----+---------+-------+

For example,

create table public_keys (username VARCHAR(10) NOT NULL, fingerprint VARCHAR(50) NOT NULL, cutoff_date DATE NOT NULL, PRIMARY KEY (fingerprint));

An sql user also needs to be able to run SELECT and INSERT. This user should not be able to update rows after creatation or delete them.
For example, the following could be used to setup a user 'kms_user'

CREATE USER 'kms_user'@'localhost' IDENTIFIED BY 'userpassword';
GRANT SELECT,INSERT kmsdb.public_keys TO 'kms_user'@'localhost';

For the validate_keys script to work it needs to be able to connect to this database. The connect details could be added to a script called "mysql_connect" in the same directory as validate_keys. For example, the following would connect to a local mariadb database with user "kms_user" and password "kms_password". SQL commands are given to it via the command line options. 

#!/bin/bash
mysql -u kms_user -pkms_password -D kms -ss -e "${1}"

Make use "mysql_connect" has global read and execute permissions. At this point the tests in the tests directory should run without error. 

SSHD

To intergrate the system into the ssh the following needs to be added to sshd_config.conf:

PubkeyAuthentication yes
AuthorizedKeysFile /dev/null
AuthorizedKeysCommand /usr/bin/validate_keys %u %h %k %f %t
AuthorizedKeysCommandUser %u

This runs as the user to ensure access to home directory for root squashed filesystems. Alternatively it can be run as root. Check permissions needed for your system.
