#!/bin/bash
# x-mysql

set -e

source x-stackrc

# Keep a copy here for stand-alone use
DATABASE_USER=${DATABASE_USER:-root}
DATABASE_PASSWORD=${DATABASE_PASSWORD:-superstack}
DATABASE_HOST=${DATABASE_HOST:-127.0.0.1}
SERVICE_LISTEN_ADDRESS=${SERVICE_LISTEN_ADDRESS:-0.0.0.0}
BASE_SQL_CONN=${BASE_SQL_CONN:-mysql://$DATABASE_USER:$DATABASE_PASSWORD@$DATABASE_HOST}

source ini-config.inc
source lib.inc

function cleanup_database {
    stop_service $MYSQL
    # Get ruthless with mysql
#    apt_get purge -y mysql* mariadb*
    sudo rm -rf /var/lib/mysql
    sudo rm -rf /etc/mysql
}

function configure_database {
    local my_conf mysql slow_log
    echo "Configuring and starting MySQL"

    my_conf=/etc/mysql/my.cnf
    mysql=mysql

    # Set the root password - only works the first time. For Ubuntu, we already
    # did that with debconf before installing the package, but we still try,
    # because the package might have been installed already.
    sudo mysqladmin -u root password $DATABASE_PASSWORD || true

    # Update the DB to give user '$DATABASE_USER'@'%' full control of the all databases:
    sudo mysql -uroot -p$DATABASE_PASSWORD -h127.0.0.1 -e "GRANT ALL PRIVILEGES ON *.* TO '$DATABASE_USER'@'%' identified by '$DATABASE_PASSWORD';"

    # Now update ``my.cnf`` for some local needs and restart the mysql service

    # Change bind-address from localhost (127.0.0.1) to any (::) and
    # set default db type to InnoDB
    iniset -sudo $my_conf mysqld bind-address "$SERVICE_LISTEN_ADDRESS"
    iniset -sudo $my_conf mysqld sql_mode TRADITIONAL
    iniset -sudo $my_conf mysqld default-storage-engine InnoDB
    iniset -sudo $my_conf mysqld max_connections 1024
    iniset -sudo $my_conf mysqld query_cache_type OFF
    iniset -sudo $my_conf mysqld query_cache_size 0

    restart_service $mysql
}

function install_database {
    # Seed configuration with mysql password so that apt-get install doesn't
    # prompt us for a password upon install.
    sudo debconf-set-selections <<MYSQL_PRESEED
mysql-server mysql-server/root_password password $DATABASE_PASSWORD
mysql-server mysql-server/root_password_again password $DATABASE_PASSWORD
mysql-server mysql-server/start_on_boot boolean true
MYSQL_PRESEED

    # while ``.my.cnf`` is not needed for OpenStack to function, it is useful
    # as it allows you to access the mysql databases via ``mysql nova`` instead
    # of having to specify the username/password each time.
    if [[ ! -e $HOME/.my.cnf ]]; then
        cat <<EOF >$HOME/.my.cnf
[client]
user=$DATABASE_USER
password=$DATABASE_PASSWORD
host=$DATABASE_HOST
EOF
        chmod 0600 $HOME/.my.cnf
    fi
    # Install mysql-server
    install_package mysql-server
}

#function recreate_database {
#    local db=$1
#    mysql -u$DATABASE_USER -p$DATABASE_PASSWORD -h$DATABASE_HOST -e "DROP DATABASE IF EXISTS $db;"
#    mysql -u$DATABASE_USER -p$DATABASE_PASSWORD -h$DATABASE_HOST -e "CREATE DATABASE $db CHARACTER SET utf8;"
#}

ACTION=${1:-none}
case $ACTION in
    stack)
        install_database
        configure_database
        ;;
    unstack)
        stop_service mysql
        ;;
    clean)
        stop_service mysql
        cleanup_database
        ;;
esac

echo "$0 Fini"
