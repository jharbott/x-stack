#!/bin/bash
# x-clients

set -e

source x-stackrc

source ini-config.inc
source lib.inc

CLIENTS_PACKAGES=python-openstackclient

function install_clients {
	install_package $CLIENTS_PACKAGES
}

ACTION=${1:-none}
case $ACTION in
    stack)
        install_clients
        ;;
    start)
        ;;
    stop|unstack)
        ;;
    clean)
        ;;
esac

echo "$0 Fini"
