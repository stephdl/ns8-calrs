#!/bin/bash

#
# Copyright (C) 2023 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

LEADER_NODE=$1
IMAGE_URL=$2
SSH_KEYFILE=${SSH_KEYFILE:-$HOME/.ssh/id_rsa}

ssh_key="$(cat $SSH_KEYFILE)"

# The cases tagged ui drive a browser against cluster-admin and write the
# screenshots the software center entry ships. They need the Playwright image,
# which is heavy, so they run on demand: the CI sets RUN_UI_TESTS, and so can
# you, RUN_UI_TESTS=true ./test-module.sh <node> <image>
if [ "${RUN_UI_TESTS}" = "true" ]; then
    runner_image=ghcr.io/marketsquare/robotframework-browser/rfbrowser-stable:v10.0.3
    ui_tag_filter=""
else
    runner_image=docker.io/python:3.11-slim
    ui_tag_filter="--exclude ui"
fi

podman run -i \
    -v .:/home/pwuser/ns8-module:z \
    --name rf-core-runner "${runner_image}" \
    bash -l -s <<EOF
    set -e
    echo "$ssh_key" > /home/pwuser/ns8-key
    set -x
    pip install -r /home/pwuser/ns8-module/tests/pythonreq.txt
    mkdir -p /home/pwuser/outputs
    cd /home/pwuser/ns8-module
    robot -v NODE_ADDR:${LEADER_NODE} \
        -v IMAGE_URL:${IMAGE_URL} \
        -v SSH_KEYFILE:/home/pwuser/ns8-key \
        ${ui_tag_filter} \
	-d /home/pwuser/outputs /home/pwuser/ns8-module/tests/
EOF

tests_res=$?

podman cp rf-core-runner:/home/pwuser/outputs tests/
podman stop rf-core-runner
podman rm rf-core-runner

exit ${tests_res}
