#!/bin/bash
# Copyright (c) 2022 MobileCoin Inc.

# Entrypoint for builder-install/mob prompt container.
# Comments marked with (mob) are functionality integrated with the mobilecoinfoundation/mobilecoin "mob" tool.

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

# (mob) should set EXTERNAL_* by default.
if [[ -n "${EXTERNAL_UID}" ]]
then
    echo_err "-- Found User ID ${EXTERNAL_UID}, setting up and switching to that user."

    is_set EXTERNAL_USER
    is_set EXTERNAL_GID
    is_set EXTERNAL_GROUP

    # (mob) uses /tmp/mobilenode to mount the mobilecoin repo. Allow override of repo path.
    REPO_PATH="${REPO_PATH:-/tmp/mobilenode}"

    # check for existing group and prefix with 'ext-' if it already exists.
    if getent group "${EXTERNAL_GROUP}" >/dev/null 2>&1
    then
        EXTERNAL_GROUP="ext-${EXTERNAL_GROUP}"
        echo_err "-- Duplicate group name found, now using: ${EXTERNAL_GROUP}"
    fi

    echo_err "-- Create group: ${EXTERNAL_GID} ${EXTERNAL_GROUP}"
    groupadd -o -g "${EXTERNAL_GID}" "${EXTERNAL_GROUP}"

    # check for existing user name and prefix with 'ext-' if it already exists.
    if getent passwd "${EXTERNAL_USER}" >/dev/null 2>&1
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

    # (mob) Copy CARGO_HOME if it doesn't exist in the working dir
    if [[ -d "${REPO_PATH}" ]]
    then
        echo_err "-- Set up .mob directory for cargo and build caching"
        mkdir -p "${REPO_PATH}/.mob"
        if [[ ! -d "${REPO_PATH}/.mob/cargo" ]]
        then
            cp -r "${CARGO_HOME}" "${REPO_PATH}/.mob/cargo"
        fi
        CARGO_HOME="${REPO_PATH}/.mob/cargo"
        export CARGO_HOME

        chown -R "${EXTERNAL_USER}:${EXTERNAL_GROUP}" "${REPO_PATH}/.mob"
    fi

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
    # (mob) fix permissions for gopath
    chown -R "${EXTERNAL_USER}:${EXTERNAL_GROUP}" "${GOPATH}"

    # (mob) fix permissions so rustup can be run by the user
    chown "${EXTERNAL_USER}:${EXTERNAL_GROUP}" "${RUSTUP_HOME}"
    chown "${EXTERNAL_USER}:${EXTERNAL_GROUP}" "${RUSTUP_HOME}/settings.toml"
    chown -R "${EXTERNAL_USER}:${EXTERNAL_GROUP}" "${RUSTUP_HOME}/tmp"
    chown -R "${EXTERNAL_USER}:${EXTERNAL_GROUP}" "${RUSTUP_HOME}/downloads"
    chown -R "${EXTERNAL_USER}:${EXTERNAL_GROUP}" "${RUSTUP_HOME}/update-hashes"
    # just change the directory so we can add new toolchains
    # recusrsive on this dir takes a looong time.
    chown "${EXTERNAL_USER}:${EXTERNAL_GROUP}" "${RUSTUP_HOME}/toolchains"

    # (mob) will mount your .ssh keys into the container at /var/tmp/user/.ssh by default.
    # We can't directly mount to /home, or useradd won't setup the home directory.
    # link ssh dir to user home if available
    if [[ -d "/var/tmp/user/.ssh" ]]
    then
        echo_err "-- Link shared .ssh dir in user home"
        ln -s /var/tmp/user/.ssh "/home/${EXTERNAL_USER}/.ssh"
    fi

    # (mob) fix permissions on Docker for MacOS magic ssh-agent socket
    if [[ -S "/run/host-services/ssh-auth.sock" ]]
    then
        echo_err "-- Fix permissions on Docker for Mac magic ssh-agent socket"
        chown "${EXTERNAL_USER}" /run/host-services/ssh-auth.sock
    fi

    # (mob) switch to mobilenode (mobilecoin repo directory) if its mounted.
    if [[ -d "${REPO_PATH}" ]]
    then
        echo_err "-- Using ${REPO_PATH} as base directory"
        cmd="cd ${REPO_PATH}; exec $*"
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
