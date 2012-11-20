#!/usr/bin/env bash
# allright reserved by Tomokazu Hirai @jedipunkz
#
# This is openstack bootstrap script code. I tested on Ubuntu Server 12.04 LTS
# and 12.10. You should set your environment parameters to deploy.conf
# such as $HOST_IP and MYAQL_PASS and ... more. And now controller or
# compute type is only supported. ;) Now I am developing for using on separated 
# compornent node and separated compute node.
#
# Usage : sudo ./deploy.sh <type>
#   type  : controller | compute | keystone | glance | cinder | horizon

set -ex

source ./deploy.conf

# --------------------------------------------------------------------------------------
# check environment
# --------------------------------------------------------------------------------------
function check_env() {
    if [[ -x $(which lsb_release 2>/dev/null) ]]; then
        CODENAME=$(lsb_release -c -s)
        if [[ $CODENAME != "precise" && $CODENAME != "quantal" ]]; then
            echo "This code was tested on precise and quantal only."
            exit 1
        fi
    else
        echo "You can run this code on Ubuntu OS only."
        exit 1
    fi
    export CODENAME
}

# --------------------------------------------------------------------------------------
# check os vendor
# --------------------------------------------------------------------------------------
function check_os() {
    VENDOR=$(lsb_release -i -s)
    export VENDER
}

function check_codename() {
    VENDOR=$(lsb_release -c -s)
    export CODENAME
}
# --------------------------------------------------------------------------------------
# package installation function
# --------------------------------------------------------------------------------------
function install_package() {
    apt-get -y install "$@"
}

# --------------------------------------------------------------------------------------
# restart function
# --------------------------------------------------------------------------------------
function restart_service() {
    check_os
    if [[ "$VENDOR" = "Ubuntu" ]]; then
        sudo /usr/bin/service $1 restart
    elif [[ "$VENDOR" = "Debian" ]]; then
        sudo /usr/sbin/service $1 restart
    else
        echo "We does not support your distribution."
        exit 1
    fi
}

# --------------------------------------------------------------------------------------
# restart function
# --------------------------------------------------------------------------------------
function start_service() {
    check_os
    if [[ "$VENDOR" = "Ubuntu" ]]; then
        sudo /usr/bin/service $1 start
    elif [[ "$VENDOR" = "Debian" ]]; then
        sudo /usr/sbin/service $1 start
    else
        echo "We does not support your distribution."
        exit 1
    fi
}

# --------------------------------------------------------------------------------------
# stop function
# --------------------------------------------------------------------------------------
function stop_service() {
    check_os
    if [[ "$VENDOR" = "Ubuntu" ]]; then
        sudo /usr/bin/service $1 stop
    elif [[ "$VENDOR" = "Debian" ]]; then
        sudo /usr/sbin/service $1 stop
    else
        echo "We does not support your distribution."
        exit 1
    fi
}

# --------------------------------------------------------------------------------------
# initialize
# --------------------------------------------------------------------------------------
function init() {
    apt-get update
    install_package ntp
    cat <<EOF >/etc/ntp.conf
server ntp.ubuntu.com
server 127.127.1.0
fudge 127.127.1.0 stratum 10
EOF

    # setup Ubuntu Cloud Archive repository
    check_codename
    if [[ "$CODENAME" = "quantal" ]]; then
        echo "quantul don't need Ubuntu Cloud Archive repository."
    else
        echo deb http://ubuntu-cloud.archive.canonical.com/ubuntu precise-updates/folsom main >> /etc/apt/sources.list.d/folsom.list
        apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 5EDB1B62EC4926EA
        apt-get update
    fi
}


# --------------------------------------------------------------------------------------
# set shell environment
# --------------------------------------------------------------------------------------
function shell_env() {
    echo 'export SERVICE_TOKEN=admin' >> ~/openstackrc
    echo 'export OS_TENANT_NAME=admin' >> ~/openstackrc
    echo 'export OS_USERNAME=admin' >> ~/openstackrc
    echo 'export OS_PASSWORD=admin' >> ~/openstackrc
    echo "export OS_AUTH_URL=\"http://${KEYSTONE_IP}:5000/v2.0/\"" >> ~/openstackrc
    echo "export SERVICE_ENDPOINT=http://${KEYSTONE_IP}:35357/v2.0" >> ~/openstackrc
    export SERVICE_TOKEN=admin
    export OS_TENANT_NAME=admin
    export OS_USERNAME=admin
    export OS_PASSWORD=admin
    export OS_AUTH_URL="http://${KEYSTONE_IP}:5000/v2.0/"
    export SERVICE_ENDPOINT="http://${KEYSTONE_IP}:35357/v2.0"
}

# --------------------------------------------------------------------------------------
# get field function
# --------------------------------------------------------------------------------------
function get_field() {
    while read data; do
        if [ "$1" -lt 0 ]; then
            field="(\$(NF$1))"
        else
            field="\$$(($1 + 1))"
        fi
        echo "$data" | awk -F'[ \t]*\\|[ \t]*' "{print $field}"
    done
}

# --------------------------------------------------------------------------------------
# install mysql
# --------------------------------------------------------------------------------------
function mysql_setup() {
    echo mysql-server-5.5 mysql-server/root_password password ${MYSQL_PASS} | debconf-set-selections
    echo mysql-server-5.5 mysql-server/root_password_again password ${MYSQL_PASS} | debconf-set-selections
    install_package mysql-server python-mysqldb
    sed -i -e 's/127.0.0.1/0.0.0.0/' /etc/mysql/my.cnf
    restart_service mysql
}

# --------------------------------------------------------------------------------------
# install keystone
# --------------------------------------------------------------------------------------
function keystone_setup() {
    install_package keystone python-keystone python-keystoneclient
    
    mysql -uroot -p${MYSQL_PASS} -e 'CREATE DATABASE keystone;'
    mysql -uroot -p${MYSQL_PASS} -e 'CREATE USER keystoneUser;'
    mysql -uroot -p${MYSQL_PASS} -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystoneUser'@'%';"
    mysql -uroot -p${MYSQL_PASS} -e "SET PASSWORD FOR 'keystoneUser'@'%' = PASSWORD('keystonePass');"
    
    sed -e "s#<HOST>#${KEYSTONE_IP}#" $BASE_DIR/conf/etc.keystone/keystone.conf > /etc/keystone/keystone.conf
    restart_service keystone
    keystone-manage db_sync
    
    # Creating Tenants
    keystone tenant-create --name admin
    keystone tenant-create --name service
    
    # Creating Users
    keystone user-create --name admin --pass admin --email admin@example.com
    keystone user-create --name nova --pass nova --email admin@example.com
    keystone user-create --name glance --pass glance --email admin@example.com
    keystone user-create --name cinder --pass cinder --email admin@example.com
    keystone user-create --name quantum --pass quantum --email admin@example.com
    keystone user-create --name demo --pass demo --email demo@example.com
    
    # Creating Roles
    keystone role-create --name admin
    keystone role-create --name Member
    
    # Adding Roles to Users in Tenants
    USER_LIST_ID_ADMIN=`mysql -u root -p${MYSQL_PASS} keystone -e "select id from user where name = 'admin'" --skip-column-name --silent`
    ROLE_LIST_ID_ADMIN=`mysql -u root -p${MYSQL_PASS} keystone -e "select id from role where name = 'admin'" --skip-column-name --silent`
    TENANT_LIST_ID_ADMIN=`mysql -u root -p${MYSQL_PASS} keystone -e "select id from tenant where name = 'admin'" --skip-column-name --silent`
    
    USER_LIST_ID_NOVA=`mysql -u root -p${MYSQL_PASS} keystone -e "select id from user where name = 'nova'" --skip-column-name --silent`
    TENANT_LIST_ID_SERVICE=`mysql -u root -p${MYSQL_PASS} keystone -e "select id from tenant where name = 'service'" --skip-column-name --silent`
    
    USER_LIST_ID_GLANCE=`mysql -u root -p${MYSQL_PASS} keystone -e "select id from user where name = 'glance'" --skip-column-name --silent`
    USER_LIST_ID_CINDER=`mysql -u root -p${MYSQL_PASS} keystone -e "select id from user where name = 'cinder'" --skip-column-name --silent`
    USER_LIST_ID_QUANTUM=`mysql -u root -p${MYSQL_PASS} keystone -e "select id from user where name = 'quantum'" --skip-column-name --silent`
    USER_LIST_ID_DEMO=`mysql -u root -p${MYSQL_PASS} keystone -e "select id from user where name = 'demo'" --skip-column-name --silent`
    
    ROLE_LIST_ID_MEMBER=`mysql -u root -p${MYSQL_PASS} keystone -e "select id from role where name = 'Member'" --skip-column-name --silent`
    
    # To add a role of 'admin' to the user 'admin' of the tenant 'admin'.
    keystone user-role-add --user-id $USER_LIST_ID_ADMIN --role-id $ROLE_LIST_ID_ADMIN --tenant-id $TENANT_LIST_ID_ADMIN
    
    # The following commands will add a role of 'admin' to the users 'nova', 'glance' and 'swift' of the tenant 'service'.
    keystone user-role-add --user-id $USER_LIST_ID_NOVA --role-id $ROLE_LIST_ID_ADMIN --tenant-id $TENANT_LIST_ID_SERVICE
    keystone user-role-add --user-id $USER_LIST_ID_GLANCE --role-id $ROLE_LIST_ID_ADMIN --tenant-id $TENANT_LIST_ID_SERVICE
    keystone user-role-add --user-id $USER_LIST_ID_CINDER --role-id $ROLE_LIST_ID_ADMIN --tenant-id $TENANT_LIST_ID_SERVICE
    keystone user-role-add --user-id $USER_LIST_ID_QUANTUM --role-id $ROLE_LIST_ID_ADMIN --tenant-id $TENANT_LIST_ID_SERVICE
    
    # The 'Member' role is used by Horizon and Swift. So add the 'Member' role accordingly.
    keystone user-role-add --user-id $USER_LIST_ID_ADMIN --role-id $ROLE_LIST_ID_MEMBER --tenant-id $TENANT_LIST_ID_ADMIN
    keystone user-role-add --user-id $USER_LIST_ID_DEMO --role-id $ROLE_LIST_ID_MEMBER --tenant-id $TENANT_LIST_ID_SERVICE
    
    # Creating Services
    keystone service-create --name nova --type compute --description 'OpenStack Compute Service'
    keystone service-create --name glance --type image --description 'OpenStack Image Service'
    keystone service-create --name cinder --type volume --description 'OpenStack Volume Service'
    keystone service-create --name quantum --type network --description 'OpenStack Networking Service'
    keystone service-create --name keystone --type identity --description 'OpenStack Identity Service'
    keystone service-create --name ec2 --type ec2 --description 'EC2 Service'
    
    keystone service-list
    
    # swift, ec2, glance, volume, keystone, nova
    #SERVICE_LIST_ID_OBJECT_STORE=`mysql -u root -p${MYSQL_PASS} keystone -e "select id from service where type='object-store'" --skip-column-name --silent`
    SERVICE_LIST_ID_EC2=`mysql -u root -p${MYSQL_PASS} keystone -e "select id from service where type='ec2'" --skip-column-name --silent`
    SERVICE_LIST_ID_IMAGE=`mysql -u root -p${MYSQL_PASS} keystone -e "select id from service where type='image'" --skip-column-name --silent`
    SERVICE_LIST_ID_VOLUME=`mysql -u root -p${MYSQL_PASS} keystone -e "select id from service where type='volume'" --skip-column-name --silent`
    SERVICE_LIST_ID_IDENTITY=`mysql -u root -p${MYSQL_PASS} keystone -e "select id from service where type='identity'" --skip-column-name --silent`
    SERVICE_LIST_ID_COMPUTE=`mysql -u root -p${MYSQL_PASS} keystone -e "select id from service where type='compute'" --skip-column-name --silent`
    SERVICE_LIST_ID_NETWORK=`mysql -u root -p${MYSQL_PASS} keystone -e "select id from service where type='network'" --skip-column-name --silent`
    
    # Creating Endpoints
    keystone endpoint-create --region myregion --service_id $SERVICE_LIST_ID_EC2 --publicurl "http://${NOVA_IP}:8773/services/Cloud" --adminurl "http://${NOVA_IP}:8773/services/Admin" --internalurl "http://${NOVA_IP}:8773/services/Cloud"
    keystone endpoint-create --region myregion --service_id $SERVICE_LIST_ID_IDENTITY --publicurl "http://${KEYSTONE_IP}:5000/v2.0" --adminurl "http://${KEYSTONE_IP}:35357/v2.0" --internalurl "http://${KEYSTONE_IP}:5000/v2.0"
    keystone endpoint-create --region myregion --service-id $SERVICE_LIST_ID_NETWORK --publicurl "http://${QUANTUM_IP}:9696/" --adminurl "http://${QUANTUM_IP}:9696/" --internalurl "http://${QUANTUM_IP}:9696/"
    keystone endpoint-create --region myregion --service_id $SERVICE_LIST_ID_VOLUME --publicurl "http://${NOVA_IP}:8776/v1/\$(tenant_id)s" --adminurl "http://${NOVA_IP}:8776/v1/\$(tenant_id)s" --internalurl "http://${NOVA_IP}:8776/v1/\$(tenant_id)s"
    keystone endpoint-create --region myregion --service_id $SERVICE_LIST_ID_IMAGE --publicurl "http://${GLANCE_IP}:9292/v2" --adminurl "http://${GLANCE_IP}:9292/v2" --internalurl "http://${GLANCE_IP}:9292/v2"
    keystone endpoint-create --region myregion --service_id $SERVICE_LIST_ID_COMPUTE --publicurl "http://${NOVA_IP}:8774/v2/\$(tenant_id)s" --adminurl "http://${NOVA_IP}:8774/v2/\$(tenant_id)s" --internalurl "http://${NOVA_IP}:8774/v2/\$(tenant_id)s"
}

# --------------------------------------------------------------------------------------
# install glance
# --------------------------------------------------------------------------------------
function glance_setup() {
    #install_package glance glance-api glance-client glance-common glance-registry python-glance python-mysqldb python-keystone python-keystoneclient mysql-client python-glanceclient
    install_package glance glance-api glance-common glance-registry python-glance python-mysqldb python-keystone python-keystoneclient mysql-client python-glanceclient
    
    mysql -uroot -p${MYSQL_PASS} -e "CREATE DATABASE glance;"
    mysql -uroot -p${MYSQL_PASS} -e "GRANT ALL ON glance.* TO 'glanceUser'@'%' IDENTIFIED BY 'glancePass';"
    
    sed -e "s#<KEYSTONE_IP>#${KEYSTONE_IP}#" -e "s#<DB_IP>#${DB_IP}#" $BASE_DIR/conf/etc.glance/glance-api.conf > /etc/glance/glance-api.conf
    sed -e "s#<KEYSTONE_IP>#${KEYSTONE_IP}#" -e "s#<DB_IP>#${DB_IP}#" $BASE_DIR/conf/etc.glance/glance-registry.conf > /etc/glance/glance-registry.conf
    
    restart_service glance-registry
    restart_service glance-api
    glance-manage db_sync

    # install cirros 0.3.0 x86_64 os image
    wget https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img
    glance add name="Cirros 0.3.0 x86_64" is_public=true container_format=ovf disk_format=qcow2 < cirros-0.3.0-x86_64-disk.img
}

# --------------------------------------------------------------------------------------
# install openvswitch
# --------------------------------------------------------------------------------------
function openvswitch_setup() {
    check_codename
    if [[ "$CODENAME" = "precise" ]]; then
        install_package openvswitch-switch openvswitch-datapath-dkms
    else
        install_package openvswitch-switch
    fi
    ovs-vsctl add-br br-int
    ovs-vsctl add-br br-eth1
    ovs-vsctl add-port br-eth1 ${DATA_NIC}
    ovs-vsctl add-br br-ex
    ovs-vsctl add-port br-ex ${PUBLIC_NIC}
}

# --------------------------------------------------------------------------------------
# install quantum
# --------------------------------------------------------------------------------------
quantum_setup() {
    install_package quantum-server python-cliff python-pyparsing quantum-plugin-openvswitch quantum-plugin-openvswitch-agent quantum-dhcp-agent quantum-l3-agent
    mysql -u root -p${MYSQL_PASS} -e "CREATE DATABASE quantum;"
    mysql -u root -p${MYSQL_PASS} -e "GRANT ALL ON quantum.* TO 'quantumUser'@'%' IDENTIFIED BY 'quantumPass';"
    
    sed -e "s#<KEYSTONE_IP>#${KEYSTONE_IP}#" $BASE_DIR/conf/etc.quantum/api-paste.ini > /etc/quantum/api-paste.ini
    sed -e "s#<KEYSTONE_IP>#${KEYSTONE_IP}#" $BASE_DIR/conf/etc.quantum/l3_agent.ini > /etc/quantum/l3_agent.ini
    sed -e "s#<RABBIT_IP>#${RABBIT_IP}#" $BASE_DIR/conf/etc.quantum/quantum.conf > /etc/quantum/quantum.conf
    if [[ "$NETWORK_TYPE" = "gre" ]]; then
        sed -e "s#<QUANTUM_IP>#${QUANTUM_IP}#" -e "s#<DB_IP>#${DB_IP}#" $BASE_DIR/conf/etc.quantum.plugins.openvswitch/ovs_quantum_plugin.ini.gre > /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini
    elif [[ "$NETWORK_TYPE" = "vlan" ]]; then
        sed -e "s#<DB_IP>#${DB_IP}#" $BASE_DIR/conf/etc.quantum.plugins.openvswitch/ovs_quantum_plugin.ini.vlan > /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini
    else
        echo "<network_type> must be 'gre' or 'vlan'."
        exit 1
    fi
    
    
    restart_service quantum-server
    restart_service quantum-plugin-openvswitch-agent
    restart_service quantum-dhcp-agent
    restart_service quantum-l3-agent
}

# --------------------------------------------------------------------------------------
# create network via quantum
# --------------------------------------------------------------------------------------
function create_network() {
    if [[ "$NETWORK_TYPE" = "gre" ]]; then
        # create internal network
        TENANT_ID=$(keystone tenant-list | grep " service " | get_field 1)
        INT_NET_ID=$(quantum net-create --tenant-id ${TENANT_ID} int_net | grep ' id ' | get_field 2)
        INT_SUBNET_ID=$(quantum subnet-create --tenant-id ${TENANT_ID} --ip_version 4 --gateway ${INT_NET_GATEWAY} ${INT_NET_ID} ${INT_NET_RANGE} | grep ' id ' | get_field 2)
        quantum subnet-update ${INT_SUBNET_ID} list=true --dns_nameservers 8.8.8.8 8.8.4.4
        INT_ROUTER_ID=$(quantum router-create --tenant-id ${TENANT_ID} router-admin | grep ' id ' | get_field 2)
        quantum router-interface-add ${INT_ROUTER_ID} ${INT_SUBNET_ID}
        # create external network
        EXT_NET_ID=$(quantum net-create ext_net -- --router:external=True | grep ' id ' | get_field 2)
        quantum subnet-create --gateway=${EXT_NET_GATEWAY} --allocation-pool start=${EXT_NET_START},end=${EXT_NET_END} ${EXT_NET_ID} ${EXT_NET_RANGE} -- --enable_dhcp=False
        quantum router-gateway-set ${INT_ROUTER_ID} ${EXT_NET_ID}
    elif [[ "$NETWORK_TYPE" = "vlan" ]]; then
        # create internal network
        TENANT_ID=$(keystone tenant-list | grep " service " | get_field 1)
        INT_NET_ID=$(quantum net-create --tenant-id ${TENANT_ID} int_net --provider:network_type vlan --provider:physical_network physnet1 --provider:segmentation_id 1024| grep ' id ' | get_field 2)
        INT_SUBNET_ID=$(quantum subnet-create --tenant-id ${TENANT_ID} --ip_version 4 --gateway ${INT_NET_GATEWAY} ${INT_NET_ID} ${INT_NET_RANGE} | grep ' id ' | get_field 2)
        quantum subnet-update ${INT_SUBNET_ID} list=true --dns_nameservers 8.8.8.8 8.8.4.4
        INT_ROUTER_ID=$(quantum router-create --tenant-id ${TENANT_ID} router-admin | grep ' id ' | get_field 2)
        quantum router-interface-add ${INT_ROUTER_ID} ${INT_SUBNET_ID}
        # create external network
        EXT_NET_ID=$(quantum net-create ext_net -- --router:external=True | grep ' id ' | get_field 2)
        quantum subnet-create --gateway=${EXT_NET_GATEWAY} --allocation-pool start=${EXT_NET_START},end=${EXT_NET_END} ${EXT_NET_ID} ${EXT_NET_RANGE} -- --enable_dhcp=False
        quantum router-gateway-set ${INT_ROUTER_ID} ${EXT_NET_ID}
    else
        echo "network type : gre, vlan"
        echo "no such parameter of network type"
        exit 1
    fi
}

# --------------------------------------------------------------------------------------
# install nova
# --------------------------------------------------------------------------------------
function nova_setup() {
    install_package kvm libvirt-bin pm-utils
    virsh net-destroy default
    virsh net-undefine default
    restart_service libvirt-bin
    
    install_package nova-api nova-cert nova-common novnc nova-compute-kvm nova-consoleauth nova-scheduler nova-novncproxy rabbitmq-server vlan bridge-utils
    mysql -u root -p${MYSQL_PASS} -e "CREATE DATABASE nova;"
    mysql -u root -p${MYSQL_PASS} -e "GRANT ALL ON nova.* TO 'novaUser'@'%' IDENTIFIED BY 'novaPass';"
    
    sed -e "s#<KEYSTONE_IP>#${KEYSTONE_IP}#" $BASE_DIR/conf/etc.nova/api-paste.ini > /etc/nova/api-paste.ini
    sed -e "s#<KEYSTONE_IP>#${KEYSTONE_IP}#" -e "s#<NOVA_IP>#${NOVA_IP}#" -e "s#<GLANCE_IP>#${GLANCE_IP}#" -e "s#<QUANTUM_IP>#${QUANTUM_IP}#" -e "s#<DB_IP>#${DB_IP}#" -e "s#<COMPUTE_IP>#127.0.0.1#" $BASE_DIR/conf/etc.nova/nova.conf > /etc/nova/nova.conf
    
    chown -R nova. /etc/nova
    chmod 644 /etc/nova/nova.conf
    nova-manage db sync
    cd /etc/init.d/; for i in $( ls nova-* ); do sudo service $i restart; done
    nova-manage service list
}

# --------------------------------------------------------------------------------------
# install additional nova
# --------------------------------------------------------------------------------------
function add_nova_setup() {
    # etc 
    install_package vlan bridge-utils kvm libvirt-bin pm-utils
    virsh net-destroy default
    virsh net-undefine default
    # openvswitch
    install_package openvswitch-switch
    ovs-vsctl add-br br-int
    ovs-vsctl add-br br-eth1
    ovs-vsctl add-port br-eth1 ${DATA_NIC_COMPUTE}
    # quantum setup
    install_package quantum-plugin-openvswitch-agent
    if [[ "$NETWORK_TYPE" = "gre" ]]; then
        sed -e "s#<QUANTUM_IP>#${QUANTUM_IP}#" -e "s#<DB_IP>#${DB_IP}#" $BASE_DIR/conf/etc.quantum.plugins.openvswitch/ovs_quantum_plugin.ini.gre > /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini
    elif [[ "$NETWORK_TYPE" = "vlan" ]]; then
        sed -e "s#<DB_IP>#${DB_IP}#" $BASE_DIR/conf/etc.quantum.plugins.openvswitch/ovs_quantum_plugin.ini.vlan > /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini
    else
        echo "<network_type> must be 'gre' or 'vlan'."
        exit 1
    fi
    sed -e "s#<RABBIT_IP>#${RABBIT_IP}#" $BASE_DIR/conf/etc.quantum/quantum.conf > /etc/quantum/quantum.conf
    service quantum-plugin-openvswitch-agent restart
    # nova setup
    install_package nova-api-metadata nova-compute-kvm
    sed -e "s#<KEYSTONE_IP>#${KEYSTONE_IP}#" $BASE_DIR/conf/etc.nova/api-paste.ini > /etc/nova/api-paste.ini
    sed -e "s#<KEYSTONE_IP>#${KEYSTONE_IP}#" -e "s#<NOVA_IP>#${NOVA_IP}#" -e "s#<GLANCE_IP>#${GLANCE_IP}#" -e "s#<QUANTUM_IP>#${QUANTUM_IP}#" -e "s#<DB_IP>#${DB_IP}#" -e "s#<COMPUTE_IP>#${ADD_NOVA_IP}#" $BASE_DIR/conf/etc.nova/nova.conf > /etc/nova/nova.conf
    cp $BASE_DIR/conf/etc.nova/nova-compute.conf /etc/nova/nova-compute.conf
    
    chown -R nova. /etc/nova
    chmod 644 /etc/nova/nova.conf
    nova-manage db sync
    cd /etc/init.d/; for i in $( ls nova-* ); do sudo service $i restart; done
    nova-manage service list
}

# --------------------------------------------------------------------------------------
# install cinder
# --------------------------------------------------------------------------------------
function cinder_setup() {
    install_package cinder-api cinder-scheduler cinder-volume iscsitarget open-iscsi iscsitarget-dkms
    mysql -uroot -p${MYSQL_PASS} -e "CREATE DATABASE cinder;"
    mysql -uroot -p${MYSQL_PASS} -e "GRANT ALL ON cinder.* TO 'cinderUser'@'%' IDENTIFIED BY 'cinderPass';"
    
    sed -e "s#<KEYSTONE_IP>#${KEYSTONE_IP}#" $BASE_DIR/conf/etc.nova/api-paste.ini > /etc/nova/api-paste.ini
    
    sed -e "s#<KEYSTONE_IP>#${KEYSTONE_IP}#" $BASE_DIR/conf/etc.cinder/api-paste.ini > /etc/cinder/api-paste.ini
    sed -e "s#<DB_IP>#${DB_IP}#" $BASE_DIR/conf/etc.cinder/cinder.conf > /etc/cinder/cinder.conf
    
    cinder-manage db sync
    pvcreate ${CINDER_VOLUME}
    vgcreate cinder-volumes ${CINDER_VOLUME}
    restart_service cinder-volume
    restart_service cinder-api
}

# --------------------------------------------------------------------------------------
# install horizon
# --------------------------------------------------------------------------------------
function horizon_setup() {
    install_package openstack-dashboard memcached
    cp $BASE_DIR/conf/etc.openstack-dashboard/local_settings.py /etc/openstack-dashboard/local_settings.py
    restart_service apache2
}

# --------------------------------------------------------------------------------------
# Main Function
# --------------------------------------------------------------------------------------
case "$1" in
    allinone | controller)
        NOVA_IP=${HOST_IP}
        CINDER_IP=${HOST_IP}
        DB_IP=${HOST_IP}
        KEYSTONE_IP=${HOST_IP}
        GLANCE_IP=${HOST_IP}
        QUANTUM_IP=${HOST_IP}
        check_env 
        shell_env
        init
        mysql_setup
        keystone_setup
        glance_setup
        openvswitch_setup
        quantum_setup
        nova_setup
        cinder_setup
        horizon_setup
        create_network
        ;;
    add_nova | compute)
        check_env
        shell_env
        init
        add_nova_setup
        ;;
    quantum)
        check_env
        shell_env
        quantum_setup
        create_network
        ;;
    cinder)
        check_env
        shell_env
        cinder_setup
        ;;
    keystone)
        check_env
        shell_env
        mysql_setup
        keystone_setup
        ;;
    glance)
        check_env
        shell_env
        glance_setup
        ;;
    nova)
        check_env
        shell_env
        nova_setup
        ;;
    horizon)
        check_env
        shell_env
        horizon_setup
        ;;
    *)
        echo "Usage : sudo ./$0 <compornent>"
        echo "<conpornent>   : allinone,controller|add_nova,compute|quantum|cinder|keystone|glance|nova|horizon|"
        echo "example) sudo ./deploy.sh controller"
        exit 1
        ;;
esac

exit 0
