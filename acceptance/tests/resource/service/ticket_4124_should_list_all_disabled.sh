#!/bin/bash

# A platform must be specified the only command line arg
# This will facilitate expansion of this tests to include
# the ability to test other OSes

RALSH_FILE=/tmp/ralsh-disabled-list-$$
SERVICE_FILE=/tmp/service-disabled-list-$$

puppet resource service | egrep -B2 "enable.*=>.*'false" | grep "service {" | awk -F"'" '{print $2}' | sort  > "$RALSH_FILE"

if [ -e "$SERVICE_FILE" ]; then
  rm "$SERVICE_FILE"
fi

SERVICEDIR='/etc/init.d'
for SERVICE in $( ls "$SERVICEDIR" | sort | egrep -v "(functions|halt|killall|single|linuxconf)" ) ; do
  if ! chkconfig "$SERVICE"; then
    echo "$SERVICE" >> "$SERVICE_FILE"
  fi
done

if diff "$RALSH_FILE" "$SERVICE_FILE" ; then
  echo "Ralsh and system service count agree"
  exit 0
else
  echo "Ralsh and system service count NOT in agreement"
  exit 1
fi
