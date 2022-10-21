# Overview

Simple script to check public key fingerprints against a database for expairy dates. It assumes mysql but should be simple enough to port.
Takes the inputs from the AuthorizedKeysCommand command and returns the contents of .ssh/authorized_keys if the provided key is still valid and nothing if it is not.

# Install

## mysql/mariadb

For RHEL 7 and later mysql server has been replaced by Mariadb

```
yum install mariadb-server
systemctl enable --now  mariadb
```

The database needs a table called public_keys with the following description


| Field       | Type        | Null | Key | Default | Extra |
|-------------|-------------|------|-----|---------|-------|
| username    | varchar(10) | NO   |     | NULL    |       |
| fingerprint | varchar(50) | NO   | PRI | NULL    |       |
| cutoff_date | date        | NO   |     | NULL    |       |


For example,

```
create table public_keys (username VARCHAR(10) NOT NULL, fingerprint VARCHAR(50) NOT NULL, cutoff_date DATE NOT NULL, PRIMARY KEY (fingerprint));
```

An sql user also needs to be able to run SELECT and INSERT. This user should not be able to update rows after creatation or delete them.
For example, the following could be used to setup a user 'kms_user'

```
CREATE USER 'kms_user'@'localhost' IDENTIFIED BY 'userpassword';
GRANT SELECT,INSERT ON kmsdb.public_keys TO 'kms_user'@'localhost';
FLUSH PRIVILEGES;
```

For the validate_keys script to work it needs to be able to connect to this database. The connect details could be set to the "**sql_connect**" variable. For example, the following would connect to a local mariadb database with user "**kms_user**" and password "**kms_password**". SQL commands are given to it via the command line options. 

```
sql_connect="mysql -u kms_user -pkms_password -D kmsdb -ss -e "
```

## MS SQL

The idea would be the same for Microsoft SQL Server but the commands are slightly different. To create the table use,

```
create table public_keys (username VARCHAR(10) NOT NULL, fingerprint VARCHAR(50) NOT NULL, cutoff_date DATE NOT NULL, PRIMARY KEY (fingerprint));
```

To create the user use,

```
CREATE USER kms_user WITH PASSWORD = 'userpassword';
GRANT SELECT,INSERT ON public_keys TO kms_user;
```

The sql_connect file can use sqlcmd provided by mssql-tools on RHEL/Centos. For example,

```
#!/bin/bash
/opt/mssql-tools/bin/sqlcmd -S server_address -U 'kms_user' -P 'userpassword' -d database -Q "${1}"
```

validate_keys expects to be able to convert the cutoff_date to a unix timestamp which isn't a builtin function in MSSQL. We get give it that function using the following,

```
CREATE FUNCTION unix_timestamp (
@ctimestamp datetime
)
RETURNS integer
AS
BEGIN
  /* Function body */
  declare @return integer
   
  SELECT @return = DATEDIFF(SECOND,{d '1970-01-01'}, @ctimestamp)
   
  return @return
END
GRANT EXECUTE ON dbo.unix_timestamp TO kms_user
```

## SSHD

To intergrate the system into the ssh the following needs to be added to sshd_config.conf:

```
PubkeyAuthentication yes
AuthorizedKeysFile /dev/null
AuthorizedKeysCommand /usr/bin/validate_keys %u %h %k %f %t
AuthorizedKeysCommandUser %u
```

This runs as the user to ensure access to home directory for root squashed filesystems. Alternatively it can be run as root. Check permissions needed for your system.

# Tests

There are a number of tests in the tests directory. These should all pass if the installtion is complete although remember that kms_user can't delete keys so these needs to be done as root or another user that has permision to do so.
