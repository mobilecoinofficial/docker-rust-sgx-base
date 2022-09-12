#!/bin/bash

# Entrypoint for builder-install/mob prompt container.
#   Set up user and set permissions

set -e

echo "Executing $0"

is_set()
{
    var_name="${1}"
    if [ -z "${!var_name}" ]
    then
        echo "${var_name} is not set."
        exit 1
    fi
}

if [[ -n "${EXTERNAL_UID}" ]]
then
    echo "Found User ID ${EXTERNAL_UID}, setting up and switching to that user."

    is_set EXTERNAL_USER
    is_set EXTERNAL_GID
    is_set EXTERNAL_GROUP

    # Add group
    groupadd -g "${EXTERNAL_GID}" "${EXTERNAL_GROUP}"

    # create the user
    useradd -m -o \
        -u "${EXTERNAL_UID}" \
        -g "${EXTERNAL_GID}" \
        -s "/bin/bash" \
        "${EXTERNAL_USER}"

    mkdir -p .mob
    # Copy CARGO_HOME if it doesn't exist in the working dir
    if [[ ! -d ".mob/cargo" ]]
    then
        cp -r "${CARGO_HOME}" .mob/cargo
    fi

    CARGO_HOME=$(pwd)/.mob/cargo

    # Set up user .bashrc
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

    # set up no password sudo access
    echo "${EXTERNAL_USER} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/user
    chmod 440 /etc/sudoers.d/user

    # set permissions for build tools.
    chown -R "${EXTERNAL_USER}:${EXTERNAL_GROUP}" ".mob"
    chown -R "${EXTERNAL_USER}:${EXTERNAL_GROUP}" "${GOPATH}"

    # now change to external user
    sudo -u "${EXTERNAL_USER}" -H /bin/bash -c "cd /tmp/mobilenode; exec $*"
else
    # or no user provided and we just exec.
    exec "$@"
fi
