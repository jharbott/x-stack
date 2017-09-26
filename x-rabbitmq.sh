#!/bin/bash
# x-rabbit

source x-stackrc

# Keep a copy here for stand-alone use
RABBIT_USERID=${RABBIT_USERID:-stackrabbit}
RABBIT_PASSWORD=${RABBIT_PASSWORD:-secretrabbit}
RABBIT_HOST=${RABBIT_HOST:-127.0.0.1}

source ini-config.inc
source lib.inc

function cleanup_rabbitmq {
    stop_service rabbit
    # in case it's not actually running, /bin/true at the end
    sudo killall epmd || sudo killall -9 epmd || /bin/true
    # Get ruthless with rabbitmq and the Erlang runtime too
    apt_get purge -y rabbitmq-server erlang*
}

function install_rabbitmq {
    # Install rabbitmq-server
    install_package rabbitmq-server
}

function rabbit_setuser {
    local user="$1" pass="$2" found="" out=""
    out=$(sudo rabbitmqctl list_users) ||
        { echo "failed to list users" 1>&2; return 1; }
    found=$(echo "$out" | awk '$1 == user { print $1 }' "user=$user")
    if [ "$found" = "$user" ]; then
        sudo rabbitmqctl change_password "$user" "$pass" ||
            { echo "failed changing pass for '$user'" 1>&2; return 1; }
    else
        sudo rabbitmqctl add_user "$user" "$pass" ||
            { echo "failed changing pass for $user"; return 1; }
    fi
    sudo rabbitmqctl set_permissions "$user" ".*" ".*" ".*"
}

function restart_rabbitmq {
    echo "Starting RabbitMQ"
    # NOTE(bnemec): Retry initial rabbitmq configuration to deal with
    # the fact that sometimes it fails to start properly.
    # Reference: https://bugzilla.redhat.com/show_bug.cgi?id=1144100
    # NOTE(tonyb): Extend the original retry logic to only restart rabbitmq
    # every second time around the loop.
    # See: https://bugs.launchpad.net/devstack/+bug/1449056 for details on
    # why this is needed.  This can bee seen on vivid and Debian unstable
    # (May 2015)
    # TODO(tonyb): Remove this when Debian and Ubuntu have a fixed systemd
    # service file.
    local i
    for i in `seq 20`; do
        local rc=0

        [[ $i -eq "20" ]] && die $LINENO "Failed to set rabbitmq password"

        if [[ $(( i % 2 )) == "0" ]] ; then
            restart_service rabbitmq-server
        fi

        rabbit_setuser "$RABBIT_USERID" "$RABBIT_PASSWORD" || rc=$?
        if [ $rc -ne 0 ]; then
            continue
        fi

        # change the rabbit password since the default is "guest"
        sudo rabbitmqctl change_password \
            $RABBIT_USERID $RABBIT_PASSWORD || rc=$?
        if [ $rc -ne 0 ]; then
            continue;
        fi

        break
    done
}

install_rabbitmq
restart_rabbitmq

