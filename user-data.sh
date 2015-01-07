#!/bin/bash
set -x

export AWS_DEFAULT_REGION=`curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk -F\" '{print $4}'`
if ! which pip; then
   easy_install -U pip
   hash -r
fi
if ! which aws; then
   pip install -U awscli
fi
aws s3 cp s3://ct-shared-bucket/bootstrap/pe-master/bootstrap.sh /tmp/bootstrap.sh
chmod 0700 /tmp/bootstrap.sh
exec /tmp/bootstrap.sh

