#!/bin/bash

PROMPT=$1

read -p "${PROMPT} [ 'y' to continue ]: " -n 1 -r -t 30
ret=$?
echo
if [[ ${ret} -eq 0 ]]
then
   if [[ ${REPLY} =~ ^[Yy] ]]
   then
	exit 0
   else
	exit -1
  fi
else [[ ${ret} -gt 128 ]]
  # input timed out
  exit 0
fi
