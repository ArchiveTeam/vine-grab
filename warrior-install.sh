#!/bin/bash

if ! sudo pip freeze | grep -q requests
then
  echo "Installing Requests"
  if ! sudo pip install requests
  then
    exit 1
  fi
fi

echo "Installing warc"
if ! sudo pip install warc
then
  exit 1
fi

exit 0

