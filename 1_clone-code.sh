#!/usr/bin/env bash

# set -x

set -e

# Code is stored in the VM itself
# CODE_ROOT=/home/vagrant

# Code is stored in a directory shared between the VM and the host.
CODE_ROOT=/vagrant
WORKING_DIR_NAME=eurorack-modules
DEV_ENV="${CODE_ROOT}/${WORKING_DIR_NAME}"
MI_REPO="https://github.com/pichenettes/eurorack.git"
PARASITES_DIR="${CODE_ROOT}/parasites"
PARASITES_REPO="https://github.com/SloBloLabs/parasites.git"
USER_GITHUB_URL="${1:-}"

# test if the dev_env directory already exists
if [ -d "$DEV_ENV" ]; then
    echo "WARNING: Working directory ${DEV_ENV} already exists, skipping git clone"
else
    # Clone the modules source code. If there was a alternative git URL
    # provided as an argument to this script, than it will be clone.
    # Otherwise, the default MI repo will be cloned.
    cd "$CODE_ROOT"
    if [ -n "$USER_GITHUB_URL" ]; then
        # Get from a clone of the custom repo.
        git clone "$USER_GITHUB_URL" "$WORKING_DIR_NAME"
        git -C "$DEV_ENV" remote add pichenettes "$MI_REPO"
    else
        # Get from the original repo.
        git clone "$MI_REPO" "$WORKING_DIR_NAME"
    fi
fi
git -C "$DEV_ENV" submodule update --init --recursive

if [ -d "$PARASITES_DIR" ]; then
    echo "WARNING: Working directory ${PARASITES_DIR} already exists, skipping git clone"
else
    cd "$CODE_ROOT"
    git clone "$PARASITES_REPO" "$PARASITES_DIR"
fi
git -C "$PARASITES_DIR" submodule update --init --recursive

# after logging in, cd directly to the code directory
if ! grep -Fqx "cd $DEV_ENV" /home/vagrant/.bashrc; then
    echo "cd $DEV_ENV" >> /home/vagrant/.bashrc
fi
