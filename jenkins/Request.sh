#!/bin/bash

# Usage: script_name.sh <ssh_username> <ssh_hostname> <limit_min> <limit_max> <result_message>

# Check number of arguments
if [ $# -ne 5 ]; then
  echo "ERROR 1: The script expects five arguments"
  exit 0
fi

# Check if any of the arguments are empty
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ] || [ -z "$5" ]; then
  echo "ERROR 2: One or more arguments are empty"
  exit 0
fi

# Execute ssh command to get disk usage percentage
df_result=$(ssh -f "$1@$2" "df -h / | tail -n 1 | tr -s ' ' | cut -d ' ' -f5 | cut -d '%' -f1")

# Check if ssh command was successful
if [ $? -ne 0 ]; then
  echo "ERROR 3: ssh command failed"
  exit 0
fi

# Check if df_result contains a number
if ! [[ $df_result =~ ^[0-9]+$ ]]; then
  echo "ERROR 4: df command did not return a number"
  exit 0
fi

# Convert df_result to integer
a=$(( df_result ))

# Check if a is less than limit_min
if (( a < $3 )); then
  echo "SUCCESS"
# Check if a is greater than limit_max
elif (( a > $4 )); then
  echo "FAILURE"
# Check if a is between limit_min and limit_max
elif (( a >= $3 && a <= $4 )); then
  echo $5
# If none of the conditions are true, exit with an error code
else
  echo "ERROR 5: Invalid df_result value"
  exit 0
fi