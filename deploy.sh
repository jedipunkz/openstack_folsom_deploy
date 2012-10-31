#!/bin/bash
# allright reserved by Tomokazu Hirai @jedipunkz
# KDDI Web Communications Inc.
#
# This is openstack bootstrap script code. I tested on Ubuntu Server 12.04 LTS
# only. You should set your environment parameters to set_env() function's 
# parameters, such as $HOST_IP and MYAQL_PASS and ... more. And now allinone
# mode was only supported. ;) Now I am developing for using on separated 
# compornent node and separated compute node.

set -ex

# --------------------------------------------------------------------------------------
# set environment
# --------------------------------------------------------------------------------------
function set_env() {
    BASE_DIR=`pwd`
    
    # for all in one
    HOST_IP='192.168.0.8'
    # for separated nodes
    NOVA_IP='192.168.0.8'
    GLANCE_IP='192.168.0.8'
    KEYSTONE_IP='192.168.0.8'
    CINDER_IP='192.168.0.8'
    DB_IP='192.168.0.8'
    QUANTUM_IP='192.168.0.8'
    # etc env
    MYSQL_PASS='secret'
    CINDER_VOLUME='/dev/sda6'
    DATA_NIC='eth1'
    PUBLIC_NIC='eth0'
    
    # quantun env
    INT_NET_GATEWAY='172.24.17.254'
    INT_NET_RANGE='172.24.17.0/24'
    EXT_NET_GATEWAY='10.200.8.1'
    EXT_NET_START='10.200.8.36'
    EXT_NET_END='10.200.8.40'
    EXT_NET_RANGE='10.200.8.0/24'
}

# --------------------------------------------------------------------------------------
# check environment
# --------------------------------------------------------------------------------------
function check_env() {
    if [[ -x $(which lsb_release 2>/dev/null) ]]; then
        CODENAME=$(lsb_release -c -s)
        if [[ "precise" != $CODENAME ]]; then
            echo "This code was tested on precise only."
            echo "If you want to run this code anyway run with 'force' option."
            echo "ex) sudo ./openstack_install_folsom.sh allinone force"
            if [[ "$1" != "force" ]]; then
                exit 1
            fi
        fi
    else
        echo "You can run this code on Ubuntu OS only."
        exit 1
    fi
}

# --------------------------------------------------------------------------------------
# initialize
# --------------------------------------------------------------------------------------
function init() {
    apt-get update
    apt-get -y install ntp
    cat <<EOF >/etc/ntp.conf
server ntp.ubuntu.com
server 127.127.1.0
fudge 127.127.1.0 stratum 10
EOF

    # setup Ubuntu Cloud Archive repository
    echo deb http://ubuntu-cloud.archive.canonical.com/ubuntu precise-updates/folsom main >> /etc/apt/sources.list.d/folsom.list
    apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 5EDB1B62EC4926EA
    apt-get update
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
    apt-get -y install mysql-server python-mysqldb
    sed -i -e 's/127.0.0.1/0.0.0.0/' /etc/mysql/my.cnf
    restart mysql
}

# --------------------------------------------------------------------------------------
# install keystone
# --------------------------------------------------------------------------------------
function keystone_setup() {
    apt-get -y install keystone python-keystone python-keystoneclient
    
    mysql -uroot -p${MYSQL_PASS} -e 'CREATE DATABASE keystone;'
    mysql -uroot -p${MYSQL_PASS} -e 'CREATE USER keystoneUser;'
    mysql -uroot -p${MYSQL_PASS} -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystoneUser'@'%';"
    mysql -uroot -p${MYSQL_PASS} -e "SET PASSWORD FOR 'keystoneUser'@'%' = PASSWORD('keystonePass');"
    
    sed -e "s#<HOST>#${KEYSTONE_IP}#" $BASE_DIR/temp/etc.keystone/keystone.conf > /etc/keystone/keystone.conf
    service keystone restart
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
    
    # Creating Roles
    keystone role-create --name admin
    keystone role-create --name Member
    
    # Listing Tenants, Users and Roles
    keystone tenant-list
    keystone user-list
    keystone role-list
    
    # Adding Roles to Users in Tenants
    USER_LIST_ID_ADMIN=`mysql -u root -p${MYSQL_PASS} keystone -e "select id from user where name = 'admin'" --skip-column-name --silent`
    ROLE_LIST_ID_ADMIN=`mysql -u root -p${MYSQL_PASS} keystone -e "select id from role where name = 'admin'" --skip-column-name --silent`
    TENANT_LIST_ID_ADMIN=`mysql -u root -p${MYSQL_PASS} keystone -e "select id from tenant where name = 'admin'" --skip-column-name --silent`
    
    USER_LIST_ID_NOVA=`mysql -u root -p${MYSQL_PASS} keystone -e "select id from user where name = 'nova'" --skip-column-name --silent`
    TENANT_LIST_ID_SERVICE=`mysql -u root -p${MYSQL_PASS} keystone -e "select id from tenant where name = 'service'" --skip-column-name --silent`
    
    USER_LIST_ID_GLANCE=`mysql -u root -p${MYSQL_PASS} keystone -e "select id from user where name = 'glance'" --skip-column-name --silent`
    USER_LIST_ID_CINDER=`mysql -u root -p${MYSQL_PASS} keystone -e "select id from user where name = 'cinder'" --skip-column-name --silent`
    USER_LIST_ID_QUANTUM=`mysql -u root -p${MYSQL_PASS} keystone -e "select id from user where name = 'quantum'" --skip-column-name --silent`
    
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
    #apt-get -y install glance glance-api glance-client glance-common glance-registry python-glance python-mysqldb python-keystone python-keystoneclient mysql-client python-glanceclient
    apt-get -y install glance glance-api glance-common glance-registry python-glance python-mysqldb python-keystone python-keystoneclient mysql-client python-glanceclient
    
    mysql -uroot -p${MYSQL_PASS} -e "CREATE DATABASE glance;"
    mysql -uroot -p${MYSQL_PASS} -e "GRANT ALL ON glance.* TO 'glanceUser'@'%' IDENTIFIED BY 'glancePass';"
    
    sed -e "s#<KEYSTONE_IP>#${KEYSTONE_IP}#" -e "s#<DB_IP>#${DB_IP}#" $BASE_DIR/temp/etc.glance/glance-api.conf > /etc/glance/glance-api.conf
    sed -e "s#<KEYSTONE_IP>#${KEYSTONE_IP}#" -e "s#<DB_IP>#${DB_IP}#" $BASE_DIR/temp/etc.glance/glance-registry.conf > /etc/glance/glance-registry.conf
    
    service glance-registry restart; service glance-api restart
    glance-manage db_sync

    # install cirros 0.3.0 x86_64 os image
    wget https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img
    glance add name="Cirros 0.3.0 x86_64" is_public=true container_format=ovf disk_format=qcow2 < cirros-0.3.0-x86_64-disk.img
}

# --------------------------------------------------------------------------------------
# install openvswitch
# --------------------------------------------------------------------------------------
function openvswitch_setup() {
    apt-get -y install openvswitch-switch openvswitch-datapath-dkms
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
    apt-get -y install quantum-server python-cliff python-pyparsing quantum-plugin-openvswitch quantum-plugin-openvswitch-agent quantum-dhcp-agent quantum-l3-agent
    mysql -u root -p${MYSQL_PASS} -e "CREATE DATABASE quantum;"
    mysql -u root -p${MYSQL_PASS} -e "GRANT ALL ON quantum.* TO 'quantumUser'@'%' IDENTIFIED BY 'quantumPass';"
    
    sed -e "s#<KEYSTONE_IP>#${KEYSTONE_IP}#" $BASE_DIR/temp/etc.quantum/api-paste.ini > /etc/quantum/api-paste.ini
    sed -e "s#<KEYSTONE_IP>#${KEYSTONE_IP}#" $BASE_DIR/temp/etc.quantum/l3_agent.ini > /etc/quantum/l3_agent.ini
    sed -e "s#<QUANTUM_IP>#${QUANTUM_IP}#" -e "s#<DB_IP>#${DB_IP}#" $BASE_DIR/temp/etc.quantum.plugins.openvswitch/ovs_quantum_plugin.ini > /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini
    
    service quantum-server restart
    service quantum-plugin-openvswitch-agent restart
    service quantum-dhcp-agent restart
    service quantum-l3-agent restart
}

# --------------------------------------------------------------------------------------
# create network via quantum
# --------------------------------------------------------------------------------------
function create_network() {
    # create internal network
    TENANT_ID=$(keystone tenant-list | grep " admin " | get_field 1)
    INT_NET_ID=$(quantum net-create --tenant-id ${TENANT_ID} int_net | grep ' id ' | get_field 2)
    INT_SUBNET_ID=$(quantum subnet-create --tenant-id ${TENANT_ID} --ip_version 4 --gateway ${INT_NET_GATEWAY} ${INT_NET_ID} ${INT_NET_RANGE} | grep ' id ' | get_field 2)
    quantum subnet-update ${INT_SUBNET_ID} list=true --dns_nameservers 8.8.8.8 8.8.4.4
    INT_ROUTER_ID=$(quantum router-create --tenant-id ${TENANT_ID} router-admin | grep ' id ' | get_field 2)
    quantum router-interface-add ${INT_ROUTER_ID} ${INT_SUBNET_ID}
    # create external network
    EXT_NET_ID=$(quantum net-create ext_net -- --router:external=True | grep ' id ' | get_field 2)
    quantum subnet-create --gateway=${EXT_NET_GATEWAY} --allocation-pool start=${EXT_NET_START},end=${EXT_NET_END} ${EXT_NET_ID} ${EXT_NET_RANGE} -- --enable_dhcp=False
    quantum router-gateway-set ${INT_ROUTER_ID} ${EXT_NET_ID}
}

# --------------------------------------------------------------------------------------
# install nova
# --------------------------------------------------------------------------------------
function nova_setup() {
    apt-get -y install kvm libvirt-bin pm-utils
    virsh net-destroy default
    virsh net-undefine default
    service libvirt-bin restart
    
    apt-get -y install nova-api nova-cert nova-common novnc nova-compute-kvm nova-consoleauth nova-scheduler nova-novncproxy rabbitmq-server vlan bridge-utils
    mysql -u root -p${MYSQL_PASS} -e "CREATE DATABASE nova;"
    mysql -u root -p${MYSQL_PASS} -e "GRANT ALL ON nova.* TO 'novaUser'@'%' IDENTIFIED BY 'novaPass';"
    
    sed -e "s#<KEYSTONE_IP>#${KEYSTONE_IP}#" $BASE_DIR/temp/etc.nova/api-paste.ini > /etc/nova/api-paste.ini
    sed -e "s#<KEYSTONE_IP>#${KEYSTONE_IP}#" -e "s#<NOVA_IP>#${NOVA_IP}#" -e "s#<GLANCE_IP>#${GLANCE_IP}#" -e "s#<QUANTUM_IP>#${QUANTUM_IP}#" -e "s#<DB_IP>#${DB_IP}#" $BASE_DIR/temp/etc.nova/nova.conf > /etc/nova/nova.conf
    
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
    apt-get -y install cinder-api cinder-scheduler cinder-volume iscsitarget open-iscsi iscsitarget-dkms
    mysql -uroot -p${MYSQL_PASS} -e "CREATE DATABASE cinder;"
    mysql -uroot -p${MYSQL_PASS} -e "GRANT ALL ON cinder.* TO 'cinderUser'@'%' IDENTIFIED BY 'cinderPass';"
    
    sed -e "s#<KEYSTONE_IP>#${KEYSTONE_IP}#" $BASE_DIR/temp/etc.nova/api-paste.ini > /etc/nova/api-paste.ini
    
    sed -e "s#<KEYSTONE_IP>#${KEYSTONE_IP}#" $BASE_DIR/temp/etc.cinder/api-paste.ini > /etc/cinder/api-paste.ini
    sed -e "s#<DB_IP>#${DB_IP}#" $BASE_DIR/temp/etc.cinder/cinder.conf > /etc/cinder/cinder.conf
    
    cinder-manage db sync
    pvcreate ${CINDER_VOLUME}
    vgcreate cinder-volumes ${CINDER_VOLUME}
    service cinder-volume restart
    service cinder-api restart
}

# --------------------------------------------------------------------------------------
# install horizon
# --------------------------------------------------------------------------------------
function horizon_setup() {
    apt-get -y install openstack-dashboard memcached
}

# --------------------------------------------------------------------------------------
# Main Function
# --------------------------------------------------------------------------------------
case "$1" in
    allinone)
        NOVA_IP=${HOST_IP}
        CINDER_IP=${HOST_IP}
        DB_IP=${HOST_IP}
        KEYSTONE_IP=${HOST_IP}
        GLANCE_IP=${HOST_IP}
        QUANTUM_IP=${HOST_IP}
        check_env $2
        set_env
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
    quantum)
        check_env
        set_env
        shell_env
        quantum_setup
        create_network
        ;;
    cinder)
        check_env
        set_env
        shell_env
        cinder_setup
        ;;
    keystone)
        check_env
        set_env
        shell_env
        mysql_setup
        keystone_setup
        ;;
    glance)
        check_env
        set_env
        shell_env
        glance_setup
        ;;
    nova)
        check_env
        set_env
        shell_env
        nova_setup
        ;;
    horizon)
        check_env
        set_env
        shell_env
        horizon_setup
        ;;
    nova_add)
        check_env
        set_env
        shell_env
        echo "wait a moment, now I am developing...:D"
        ;;
    *)
        echo $"Usage : $0 {allinone|quantum|cinder|keystone|glance|nova|horizon|nova_add}"
        exit 1
        ;;
esac

exit 0
