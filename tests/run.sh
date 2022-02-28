#!/bin/bash
#A few unit and end-to-end tests that should all pass

function assert_str {
	#Using local values, plus is reminds me of var order
	local test_name=${1}
	local truth=${2}
	local test_value=${3}
	total_tests=$(( total_tests + 1 ))
	if [ "${truth}" == "${test_value}" ] ; then
		printf "Test ${test_name}: ${GREEN}pass${NC}\n"
		total_passed=$(( total_passed + 1 ))
	else
		printf "Test ${test_name}: ${RED}fail${NC}\n"
		total_failed=$(( total_failed + 1 ))
	fi
}
function assert_int {
	#Using local values, plus is reminds me of var order
	local test_name=${1}
	local truth=${2}
	local test_value=${3}
	total_tests=$(( total_tests + 1 ))
	if [ ${truth} -eq ${test_value} ] ; then
		printf "Test ${test_name}: ${GREEN}pass${NC}\n"
		total_passed=$(( total_passed + 1 ))
	else
		printf "Test ${test_name}: ${RED}fail${NC}\n"
		total_failed=$(( total_failed + 1 ))
	fi
}

function check_readable {
	local filename=${1}
	test -e  ${filename}
	assert_int "${filename} exists" 0 ${?}
	test -r  ${filename}
	assert_int "${filename} readable" 0 ${?}

}
function check_executable {
	local filename=${1}
	check_readable ${filename}
	test -x  ${filname}
	assert_int "${filename} executable" 0 ${?}	
}

#Globals for test functions
RED="\033[0;31m"
GREEN="\033[0;32m"
NC="\033[0m" # No Color

total_tests=0
total_failed=0
total_passed=0

#Run tests

assert_int "Simple Self test" 1 1

VALIDATE_KEYS=../validate_keys
check_executable ${VALIDATE_KEYS}

#Test public keys
check_readable id_rsa_missing.pub
check_readable id_rsa_present.pub

#check keys in .ssh/authorized_keys
check_readable .ssh/authorized_keys
test_value=$(grep -c -f id_rsa_missing.pub .ssh/authorized_keys)
assert_int "id_rsa_missing.pub NOT in .ssh/authorized_keys" 0 ${test_value}
test_value=$(grep -c -f id_rsa_present.pub .ssh/authorized_keys)
assert_int "id_rsa_present.pub in .ssh/authorized_keys" 1 ${test_value}

#Check database
SQL_CONNECT=../mysql_connect
check_executable ${SQL_CONNECT}
##Check can connect
sql="show databases"
rtn=$(${SQL_CONNECT} "${sql}")
assert_int "connection to sql Database" 0 ${?}

##Check table is set up
sql="select COLUMN_NAME from INFORMATION_SCHEMA.COLUMNS where TABLE_NAME='public_keys'"
test_str=""
for column in $(${SQL_CONNECT} "${sql}"); do
	test_str="${test_str} ${column}"
done
assert_str "Table has expected columns" " username fingerprint cutoff_date" "${test_str}"

## add/remove keys tests
./cleanup_test_data

sql="INSERT INTO public_keys (username, fingerprint, cutoff_date) VALUES ('test_user', '123456789', date_add(now(),interval 365 day))"
${SQL_CONNECT} "${sql}"
sql="select count(*) from public_keys where username = 'test_user' AND fingerprint = '123456789'"
test_count=$(${SQL_CONNECT} "${sql}")
assert_int "insert new test key" 1 ${test_count}

sql="DELETE FROM public_keys WHERE username='test_user'"
${SQL_CONNECT} "${sql}"
sql="select count(*) from public_keys where username = 'test_user' AND fingerprint = '123456789'"
test_count=$(${SQL_CONNECT} "${sql}")
assert_int "should not be able to delete test keys" 1 ${test_count}

#End to end tests
./cleanup_test_data
##Successful connection
present_fingerprint=$(ssh-keygen -lf id_rsa_present.pub | awk '{ print $2 }')
present_key=$(cat id_rsa_present.pub | awk '{ print $2 }')
present_key_type=$(cat id_rsa_present.pub | awk '{ print $1 }')
sql="INSERT INTO public_keys (username, fingerprint, cutoff_date) VALUES ('test_user', '${present_fingerprint}', date_add(now(),interval 365 day))"
${SQL_CONNECT} "${sql}"
test_str=$(${VALIDATE_KEYS} "test_user" $(pwd) ${present_key} ${present_fingerprint} ${present_key_type})
assert_str "connect using present key" "$(cat .ssh/authorized_keys)" "${test_str}"

##Not in .ssh/authorized_keys
missing_fingerprint=$(ssh-keygen -lf id_rsa_missing.pub | awk '{ print $2 }')
missing_key=$(cat id_rsa_missing.pub | awk '{ print $2 }')
missing_key_type=$(cat id_rsa_missing.pub | awk '{ print $1 }')
test_str=$(${VALIDATE_KEYS} "test_user" $(pwd) ${missing_key} ${missing_fingerprint} ${missing_key_type})
assert_str "failing to connect using missing key" "" "${test_str}"

##Key timed out
./cleanup_test_data
present_fingerprint=$(ssh-keygen -lf id_rsa_present.pub | awk '{ print $2 }')
present_key=$(cat id_rsa_present.pub | awk '{ print $2 }')
present_key_type=$(cat id_rsa_present.pub | awk '{ print $1 }')
sql="INSERT INTO public_keys (username, fingerprint, cutoff_date) VALUES ('test_user', '${present_fingerprint}', date_add(now(),interval -1 day))"
${SQL_CONNECT} "${sql}"
test_str=$(${VALIDATE_KEYS} "test_user" $(pwd) ${present_key} ${present_fingerprint} ${present_key_type})
assert_str "failing to connect using out of date present key" "" "${test_str}"

#final Cleanup
./cleanup_test_data

#Summary
echo "Tests passed: ${total_passed}/${total_tests}"
echo "Tests failed: ${total_failed}/${total_tests}"
