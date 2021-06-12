#!/bin/bash

if [[ "$OSTYPE" == "linux-gnu" ]];
then
  echo "Linux is your OS"
  # Do setup for Linux
  else [[ "$OSTYPE" == "darwin" ]];
  echo "MacOS is your OS"
  # do setup for Mac
fi
