#!/bin/bash
apk add --update --no-cache python3 && ln -sf python3 /usr/bin/python
python3 -m ensurepip
pip3 install --no-cache --upgrade pip setuptools
pip3 install aws-sam-cli
cd events/cloudformation
ls
python -v
