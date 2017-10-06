#!/bin/bash
# x-keystone

set -e

source x-stackrc

source ini-config.inc
source lib.inc

KEYSTONE_CONF_DIR=/etc/keystone
KEYSTONE_CONF=$KEYSTONE_CONF_DIR/keystone.conf

# until we have https in
KEYSTONE_SERVICE_PROTOCOL=http

KEYSTONE_SERVICE_URI=${KEYSTONE_SERVICE_PROTOCOL}://${KEYSTONE_SERVICE_HOST}/identity
KEYSTONE_AUTH_URI=$KEYSTONE_SERVICE_URI

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

function bootstrap_keystone {
    sudo $BASE_BIN_DIR/keystone-manage bootstrap \
        --bootstrap-username admin \
        --bootstrap-password "$ADMIN_PASSWORD" \
        --bootstrap-project-name admin \
        --bootstrap-role-name admin \
        --bootstrap-service-name keystone \
        --bootstrap-region-id "$REGION_NAME" \
        --bootstrap-admin-url "$KEYSTONE_AUTH_URI" \
        --bootstrap-public-url "$KEYSTONE_SERVICE_URI"

    # Create additional domains, projects, users and roles
    # This closely follows DevStack's create_keystone_accounts()
    # TODO: write clouds.yaml dynamically
    openstack --os-cloud xstack-admin <<EOF
        domain create --or-show $SERVICE_DOMAIN_NAME
        project create --or-show --domain $SERVICE_DOMAIN_NAME $SERVICE_PROJECT_NAME
        role create --or-show service
        role create --or-show ResellerAdmin
        role create --or-show Member
        role create --or-show member
        role create --or-show anotherrole
        project create --or-show --domain default invisible_to_admin
        project create --or-show --domain default demo
        user create --or-show --domain default --email=demo@example.com --password secretadmin demo
        role add --project demo --user demo member
        role add --project demo --user admin admin
        role add --project demo --user demo anotherrole
        role add --project invisible_to_admin --user demo member
        project create --or-show --domain default alt_demo
        user create --or-show --domain default --email=alt_demo@example.com --password secretadmin alt_demo
        role add --project alt_demo --user alt_demo member
        role add --project alt_demo --user admin admin
        role add --project alt_demo --user alt_demo anotherrole
        group create --or-show --domain default --description 'openstack admin group' admins
        group create --or-show --domain default --description 'non-admin group' nonadmins
        role add --project demo --group nonadmins member
        role add --project demo --group nonadmins anotherrole
        role add --project alt_demo --group nonadmins member
        role add --project alt_demo --group nonadmins anotherrole
        role add --project admin --group admins admin
EOF
}

function cleanup_keystone {
    # pass
    delete_database keystone
}

function configure_keystone {
    # Be like DevStack
    iniset $KEYSTONE_CONF identity domain_specific_drivers_enabled "True"
    iniset $KEYSTONE_CONF role driver sql

    iniset $KEYSTONE_CONF cache enabled "True"
    iniset $KEYSTONE_CONF cache backend "dogpile.cache.memcached"
    iniset $KEYSTONE_CONF cache memcache_servers localhost:11211

    iniset $KEYSTONE_CONF DEFAULT public_endpoint $KEYSTONE_SERVICE_URI
    iniset $KEYSTONE_CONF DEFAULT admin_endpoint $KEYSTONE_AUTH_URI

    iniset $KEYSTONE_CONF database connection ${BASE_SQL_CONN}/keystone?charset=utf8
    iniset $KEYSTONE_CONF token provider fernet

    iniset $KEYSTONE_CONF DEFAULT logging_exception_prefix "%(asctime)s.%(msecs)03d %(process)d TRACE %(name)s %(instance)s"

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
    rm -f /var/lib/keystone/keystone.db
}

function start_keystone {
    sudo a2enmod wsgi
    sudo a2ensite keystone
    restart_service apache2
}

function stop_keystone {
    sudo a2dissite keystone
    restart_service apache2
}

ACTION=${1:-none}
case $ACTION in
    stack)
        install_keystone
        configure_keystone
        init_keystone
        start_keystone
        bootstrap_keystone
        ;;
    start)
        start_keystone
        ;;
    stop|unstack)
        stop_keystone
        ;;
    clean)
        stop_keystone
        cleanup_keystone
        ;;
esac

echo "$0 Fini"
