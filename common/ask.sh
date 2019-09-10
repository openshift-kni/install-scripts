#!/bin/bash

PROMPT=$1

read -p "${PROMPT} [ 'y' to continue ]: " -n 1 -r
echo
if [[ ${REPLY} =~ ^[Yy] ]]
then
	exit 0
else
	exit -1
fi
