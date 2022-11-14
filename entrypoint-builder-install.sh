#!/bin/bash

# Entrypoint for builder-install/mob prompt container.
#   Set up user and set permissions

set -e

is_set()
{
    var_name="${1}"
    if [ -z "${!var_name}" ]
    then
        echo "${var_name} is not set."
        exit 1
    fi
}

# Echo to stderr - print details when verbose is set.
echo_err()
{
    if [ -n "${ENTRYPOINT_VERBOSE}" ]
    then
        printf "%s\n" "$*" >&2
    fi
}

echo_err "Executing $0 with command $*"

if [[ -n "${EXTERNAL_UID}" ]]
then
    echo_err "-- Found User ID ${EXTERNAL_UID}, setting up and switching to that user."

    is_set EXTERNAL_USER
    is_set EXTERNAL_GID
    is_set EXTERNAL_GROUP

    # check for existing group and prefix with 'ext-' if it already exists.
    if getent group "${EXTERNAL_GROUP}"
    then
        EXTERNAL_GROUP="ext-${EXTERNAL_GROUP}"
        echo_err "-- Duplicate group name found, now using: ${EXTERNAL_GROUP}"
    fi

    echo_err "-- Create group: ${EXTERNAL_GID} ${EXTERNAL_GROUP}"
    groupadd -o -g "${EXTERNAL_GID}" "${EXTERNAL_GROUP}"

    # check for existing user name and prefix with 'ext-' if it already exists.
    if getent passwd "${EXTERNAL_USER}"
    then
        EXTERNAL_USER="ext-${EXTERNAL_USER}"
        echo_err "-- Duplicate user name found, now using: ${EXTERNAL_USER}"
    fi

    echo_err "-- Create user: ${EXTERNAL_UID} ${EXTERNAL_USER} "
    useradd -m -o \
        -u "${EXTERNAL_UID}" \
        -g "${EXTERNAL_GID}" \
        -s "/bin/bash" \
        "${EXTERNAL_USER}"

    echo_err "-- Set up .mob directory for cargo and build caching"
    mkdir -p .mob
    # Copy CARGO_HOME if it doesn't exist in the working dir
    if [[ ! -d ".mob/cargo" ]]
    then
        cp -r "${CARGO_HOME}" .mob/cargo
    fi

    CARGO_HOME=$(pwd)/.mob/cargo
    export CARGO_HOME

    echo_err "-- Setup user .bashrc"
    root_env=$(env)
    env_skips=("HOSTNAME" "PWD" "HOME" "LS_COLORS" "LESSCLOSE" "LESSOPEN" "SHLVL" "_")

    for pair in ${root_env}
    do
        # split pair into p array
        IFS='='; read -ra p <<< "${pair}"; unset IFS

        # skip setting user envs, we just want to pass on mob stuff
        for skip in "${env_skips[@]}"
        do
            if [[ "${p[0]}" == "${skip}" ]]
            then
                continue 2
            fi
        done

        # add export to user .bashrc
        echo "export ${p[0]}=${p[1]}" >> "/home/${EXTERNAL_USER}/.bashrc"
    done

    echo_err "-- Setup no password sudo access."
    echo "${EXTERNAL_USER} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/user
    chmod 440 /etc/sudoers.d/user

    echo_err "-- Set permissions for build tools."
    chown -R "${EXTERNAL_USER}:${EXTERNAL_GROUP}" ".mob"
    chown -R "${EXTERNAL_USER}:${EXTERNAL_GROUP}" "${GOPATH}"

    # switch to mobilenode (mobilecoin repo directory) if its mounted.
    if [[ -d "/tmp/mobilenode" ]]
    then
        echo_err "-- Using /tmp/mobilenode as base directory"
        cmd="cd /tmp/mobilenode; exec $*"
    else
        echo_err "-- Using user home as base directory"
        cmd="cd /home/${EXTERNAL_USER}; exec $*"
    fi

    echo_err "-- Change to external user"
    sudo -u "${EXTERNAL_USER}" -H /bin/bash -i -c "${cmd}"
else
    # or no user provided and we just exec.
    exec "$@"
fi
