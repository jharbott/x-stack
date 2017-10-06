# lib.inc
# well-known DevStack functions


# Control Functions
# =================
# from devstack/functions-common

function die {
    local exitcode=$?
    set +o xtrace
    local line=$1; shift
    if [ $exitcode == 0 ]; then
        exitcode=1
    fi
#    backtrace 2
    err $line "$*"
    # Give buffers a second to flush
    sleep 1
    exit $exitcode
}

function err {
    local exitcode=$?
    local xtrace
    xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local msg="[ERROR] ${BASH_SOURCE[2]}:$1 $2"
    echo $msg 1>&2;
    if [[ -n ${LOGDIR} ]]; then
        echo $msg >> "${LOGDIR}/error.log"
    fi
    $xtrace
    return $exitcode
}


# Package Functions
# =================
# from devstack/functions-common

function install_package {
    sudo DEBIAN_FRONTEND=noninteractive \
        http_proxy=${http_proxy:-} https_proxy=${https_proxy:-} \
        no_proxy=${no_proxy:-} \
        apt-get --option "Dpkg::Options::=--force-confold" --assume-yes install "$@" < /dev/null
}


# System Functions
# ================
# from devstack/functions-common

function restart_service {
    if [ -x /bin/systemctl ]; then
        sudo /bin/systemctl restart $1
    else
        sudo service $1 restart
    fi
}

function stop_service {
    if [ -x /bin/systemctl ]; then
        sudo /bin/systemctl stop $1
    else
        sudo service $1 stop
    fi
}


# Opther Functions
# ================

function delete_database {
    local db=$1
    mysql -u$DATABASE_USER -p$DATABASE_PASSWORD -h$DATABASE_HOST -e "DROP DATABASE IF EXISTS $db;"
}

function recreate_database {
    local db=$1
    delete_database $db
    mysql -u$DATABASE_USER -p$DATABASE_PASSWORD -h$DATABASE_HOST -e "CREATE DATABASE $db CHARACTER SET utf8;"
}

