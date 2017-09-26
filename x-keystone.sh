#!/bin/bash
# x-keystone

source x-stackrc

source ini-config.inc
source lib.inc

KEYSTONE_CONF_DIR=/etc/keystone
KEYSTONE_CONF=$KEYSTONE_CONF_DIR/keystone.conf

function _config_keystone_apache_wsgi {
    local keystone_apache_conf
    keystone_apache_conf=${APACHE_CONF_DIR}/keystone.conf
    keystone_ssl_listen="#"
    local keystone_ssl=""
    local keystone_certfile=""
    local keystone_keyfile=""
    local keystone_service_port=$KEYSTONE_SERVICE_PORT
    local keystone_auth_port=$KEYSTONE_AUTH_PORT
	local keystone_user=keystone
    local venv_path=""

    sudo cp $BASE_DIR/files/apache-keystone.template $keystone_apache_conf
    sudo sed -e "
        s|%PUBLICPORT%|$keystone_service_port|g;
        s|%ADMINPORT%|$keystone_auth_port|g;
        s|%APACHE_NAME%|$APACHE_NAME|g;
        s|%SSLLISTEN%|$keystone_ssl_listen|g;
        s|%SSLENGINE%|$keystone_ssl|g;
        s|%SSLCERTFILE%|$keystone_certfile|g;
        s|%SSLKEYFILE%|$keystone_keyfile|g;
        s|%USER%|$keystone_user|g;
        s|%VIRTUALENV%|$venv_path|g
        s|%KEYSTONE_BIN%|$BASE_BIN_DIR|g
    " -i $keystone_apache_conf
}

function configure_keystone {
    # Be like DevStack
    iniset $KEYSTONE_CONF identity domain_specific_drivers_enabled "True"
    iniset $KEYSTONE_CONF role driver sql

    iniset $KEYSTONE_CONF cache enabled "True"
    iniset $KEYSTONE_CONF cache backend "dogpile.cache.memcached"
    iniset $KEYSTONE_CONF cache memcache_servers localhost:11211

    iniset $KEYSTONE_CONF database connection ${BASE_SQL_CONN}/keystone?charset=utf8

	_config_keystone_apache_wsgi
}

function init_keystone {
    recreate_database keystone

    local args="--keystone-user keystone --keystone-group keystone"

    sudo $BASE_BIN_DIR/keystone-manage --config-file $KEYSTONE_CONF db_sync

    sudo rm -rf "$KEYSTONE_CONF_DIR/fernet-keys/"
    sudo $BASE_BIN_DIR/keystone-manage --config-file $KEYSTONE_CONF fernet_setup $args
}

function install_keystone {
    # Don't start immediately
    echo "manual" > /etc/init/keystone.override

    install_package keystone python-keystoneauth1 python-keystoneclient python-keystonemiddleware apache2 libapache2-mod-wsgi memcached python-memcache
	sudo a2enmod wsgi
	restart_service apache2
}

install_keystone
configure_keystone
init_keystone

# Bootstrap Keystone

# Init fernet


