#!/bin/bash

SECRET_LENGTH="$1"
ANSIBLE_USER="$2"
NETWORK_NAME="$3"
FILENAME="$4"
SECRET="$5"
PATH="/home/${ANSIBLE_USER}/${NETWORK_NAME}/${FILENAME}"
head="/usr/bin/head"
tr="/usr/bin/tr"
cat="/bin/cat"

if [[ ! -f $PATH ]]
then
    if [[ -z "$SECRET" ]]
    then
        $head /dev/urandom | $tr -dc A-Za-z0-9 | $head -c ${SECRET_LENGTH} > $PATH
        echo -n $($cat $PATH)

    else
        echo -n $SECRET > $PATH
    fi
else
    echo -n $($cat $PATH)
fi
