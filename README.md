OpenStack Folsom Installation Bash Script
=======================

OpenStack Folsom Installation Bash Script for Ubuntu Server 12.04 or 12.10

In Japanese... <https://github.com/jedipunkz/openstack_folsom_deploy/blob/master/README_jp.md>

Author
----
Tomokazu Hirai @jedipunkz

Twitter : <https://twitter.com/jedipunkz>
Blog    : <http://jedipunkz.github.com>

Notice
----

This script was tested ...

* all in one node with nova-network
* separated nodes (controller, compute x N) with nova-network
* all in one node with quantum
* separated nodes (controller, network, compute x N) with quantum

so, now I do not support separated nodes for each service (keystone, glance,
nova, etc...). If you want to do this with separated nodes mode, please tell
me or fork it. :D

Motivation
----

devstack is very usefull for me. I am using devstack for understanding
openstack, especially Quantum ! ;) but when I reboot devstack node, all of
openstack compornents was not booted. That is not good for me. and I wanted to
use Ubuntu Cloud Archive packages or Ubuntu Package with 12.10.

Require Environment with quanum
----

You need 1 or more node(s) with Ubuntu Server 12.04 LTS / 12.10.

You should have a machine with 3 NICs. eth0 is public network interface. eth1
is VM (data) network interface, this will be used for communication to other
VMs on other compute nodes. eth2 is completely for management.

Quantum was designed based on 4 networks, public/data/management/api. This script
designed based on 3 networks (if you want 4 networks, you can do it with this).
public/data/management & api. All of APIs will be listening on management networks
interface.

And you need a disk device (such as /dev/sda6) for cinder service.



Require Environment with nova-network
----

If you choose nova-network, it is simple. You need 1 NIC only. And you need a
disk device (such as /dev/sda6) for cinder service.


How to use with quantum
====

How to use all in one node with quantum
----

#### Preconfigured Architecture

    management segment 172.16.1.0/24
    +---------------------------------------------------------------------------------
    |
    |
    | eth2 172.16.1.11
    +------------+
    |            | eth1
    | all in one | vlan/gre seg = 172.24.17.0/24
    |            | data segment = 172.16.2.0/24
    +------------+ 172.16.2.11
    | eth0 10.200.8.11
    |
    |
    +---------------------------------------------------------------------------------
    |       public segment 10.200.8.0/24
    |
    | 10.200.8.1
    +-----------+
    | GW Router |-> The Internet
    +-----------+

fig.1 all in one with quantum

#### OS Install

Please make disk partition such as /dev/sda6. Script make this disk partition
to use by Cinder.

#### Set up network interfaces

Set up network configuration.

    % sudo vim /etc/network/interfaces
    auto lo
    iface lo inet loopback
    
    auto eth0
    iface eth0 inet static
        up ifconfig $IFACE 0.0.0.0 up
        up ip link set $IFACE promisc on
        down ip link set $IFACE promisc off
        down ifconfig $IFACE down
        address 10.200.8.16
        netmask 255.255.255.0
        dns-nameservers 8.8.8.8 8.8.4.4
        dns-search cpi.ad.jp
    
    auto eth1
    iface eth1 inet static
        address 172.16.2.11
        netmask 255.255.255.0
    
    auto eth2
    iface eth2 inet static
        address 172.16.1.11
        netmask 255.255.255.0
        gateway 172.16.1.1
        dns-nameservers 8.8.8.8 8.8.4.4
    % sudo /etc/init.d/networking restart

Clone this scripts to your target node.

    % git clone https://github.com/jedipunkz/openstack_folsom_deploy.git
    % cd openstack_folsom_deploy

#### Edit parameters

Update these environment in deploy_with_quantum.conf

    BASE_DIR=`pwd`
    HOST_IP='172.16.1.11'
    HOST_PUB_IP='10.200.8.11'
    
    MYSQL_PASS='secret'
    CINDER_VOLUME='/dev/sda6'
    DATA_NIC='eth1'
    PUBLIC_NIC='eth0'
    
    NETWORK_TYPE='gre'
    INT_NET_GATEWAY='172.24.17.254'
    INT_NET_RANGE='172.24.17.0/24'
    EXT_NET_GATEWAY='10.200.8.1'
    EXT_NET_START='10.200.8.36'
    EXT_NET_END='10.200.8.40'
    EXT_NET_RANGE='10.200.8.0/24'
    
    OS_IMAGE_URL="https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img"
    OS_IMAGE_NAME="Cirros 0.3.0 x86_64"

#### Run script

Run this script.

	% sudo ./deploy.sh allinone quantum # wait some minutes...

That's all and You've done :D

Now you can create and boot VMs on Horizon (http://${HOST_IP}/horizon)  with user: demo, pass: demo.

How to use 3 nodes (controller, network, compute) mode with quantum
----

#### Preconfigured Architecture

    management segment 172.16.1.0/24
    +--------------------------------------------+------------------+-----------------
    |                                            |                  |
    |                                            |                  |
    | eth2 172.16.1.12                           | eth2 172.16.1.13 | eth2 172.16.1.11
    +------------+                               +-----------+      +------------+
    |            | eth1 ------------------- eth1 |           |      |            |
    |  network   | vlan/gre seg = 172.24.17.0/24 |  compute  |      | controller |
    |    node    | data segment = 172.16.2.0/24  |   node    |      |    node    |
    +------------+ 172.16.2.13       172.16.2.12 +-----------+      +------------+
    | eth0 10.200.8.12                                              | eth0 10.200.8.11
    |                                                               |
    |                                                               |
    +--------------------------------------------+------------------+-----------------
    |       public segment 10.200.8.0/24
    |
    | 10.200.8.1
    +-----------+
    | GW Router |-> The Internet
    +-----------+

fig.2 separated nodes with quantum

#### OS Install

Please make disk partition such as /dev/sda6 on Controller node. Script make this disk partition
to use by Cinder.

#### get script

If you have a plan to build separated by function (controller, network,
compute nodes), please run deploy.sh with 'controller', 'network', 'compute' option.
Parameters of deploy.conf must be same as controller's one.

    controller% git clone https://github.com/jedipunkz/openstack_folsom_deploy.git

#### Edit parameters

Update parameters of deploy_with_quantum.conf

    BASE_DIR=`pwd`
    CONTROLLER_NODE_IP='172.16.1.11'
    CONTROLLER_NODE_PUB_IP='10.200.8.11'
    NETWORK_NODE_IP='172.16.1.12'
    COMPUTE_NODE_IP='172.16.1.13'
    DATA_NIC_COMPUTE='eth1'
    
    MYSQL_PASS='secret'
    CINDER_VOLUME='/dev/sda6'
    DATA_NIC='eth1'
    PUBLIC_NIC='eth0'
    
    NETWORK_TYPE='gre'
    INT_NET_GATEWAY='172.24.17.254'
    INT_NET_RANGE='172.24.17.0/24'
    EXT_NET_GATEWAY='10.200.8.1'
    EXT_NET_START='10.200.8.36'
    EXT_NET_END='10.200.8.40'
    EXT_NET_RANGE='10.200.8.0/24'

OS_IMAGE_URL="https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img"
OS_IMAGE_NAME="Cirros 0.3.0 x86_64"


#### copy to other nodes

copy directory to network node and compute node.
    
    controller% scp -r openstack_folsom_deploy <network_node_ip>:~/
    controller% scp -r openstack_folsom_deploy <compute_node_ip>:~/

##### set up network interfaces

Set up NICs for each comportnent.

Controller Node's /etc/network/interfaces

    auto lo
    iface lo inet loopback

    auto eth0
    iface eth0 inet static
        address 10.200.8.11
        netmask 255.255.255.0
        gateway 10.200.8.1
        dns-nameservers 8.8.8.8 8.8.4.4
        dns-search cpi.ad.jp
    
    auto eth2
    iface eth2 inet static
        address 172.16.1.11
        netmask 255.255.255.0

Network Node's /etc/network/interfaces

    auto lo
    iface lo inet loopback
    
    auto eth0
    iface eth0 inet static
        up ifconfig $IFACE 0.0.0.0 up
        up ip link set $IFACE promisc on
        down ip link set $IFACE promisc off
        down ifconfig $IFACE down
        address 10.200.8.12
        netmask 255.255.255.0
        #gateway 10.200.8.1
        # dns-* options are implemented by the resolvconf package, if installed
        dns-nameservers 8.8.8.8 8.8.4.4
        dns-search cpi.ad.jp
    
    auto eth1
        iface eth1 inet static
        address 172.16.2.12
        netmask 255.255.255.0
    
    auto eth2
    iface eth2 inet static
        address 172.16.1.12
        netmask 255.255.255.0
        gateway 172.16.1.1
    dns-nameservers 8.8.8.8 8.8.4.4

Compoute Node's /etc/network/interfaces

    auto eth1
    iface eth1 inet static
        address 172.16.2.13
        netmask 255.255.255.0
    
    auto eth2
    iface eth2 inet static
        address 172.16.1.13
        netmask 255.255.255.0
        gateway 172.16.1.1
        dns-nameservers 8.8.8.8 8.8.4.4

#### Run this script

Deploy OpenStack for each compornent.

    controller% sudo ./deploy.sh controller quantum
    network   % sudo ./deploy.sh network quantum
    compute   % sudo ./deploy.sh compute quntum
    
You've done. Please access http://${CONTROLLER_NODE_PUB_IP}/horizon via your
browser with user: demo, pass: demo.

How to use with nova-network
====

How to use all in one mode with nova-network
----

#### Preconfigured Architecure

                                       +-----------+
    +----------------------------------| GW Router |-> The Internet
    |10.200.8.11                       +-----------+
    |eth0
    +------------+
    |            |
    | all in one |
    |            |
    +------------+

fig.3 all in one with nova-network

#### OS Install

Please make disk partition such as /dev/sda6. Script make this disk partition
to use by Cinder.

#### Set up network interfaces

Set up your network configurations to use static ip address.

    % sudo vim /etc/network/interfaces
    auto lo
    iface lo inet loopback
    
    auto eth0
    iface eth0 inet static
            address 10.200.8.11
            netmask 255.255.255.0
            gateway 10.200.8.1
            dns-nameservers 8.8.8.8 8.8.4.4

#### get scripts

Clone this scripts to your target node.

    % git clone https://github.com/jedipunkz/openstack_folsom_deploy.git
    % cd openstack_folsom_deploy

#### Edit parameters

Set up parameters of deploy_with_nova-network.conf

    BASE_DIR=`pwd`
    HOST_IP='10.200.8.11'
    
    MYSQL_PASS='secret'
    CINDER_VOLUME='/dev/sda6'
    
    FIXED_RANGE="10.0.0.0/24"
    FIXED_START_ADDR="10.0.0.2"
    FLOATING_RANGE="10.200.8.28/30"
    NETWORK_SIZE="256"
    
    OS_IMAGE_URL="https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img"
    OS_IMAGE_NAME="Cirros 0.3.0 x86_64"

#### Run this script

Run this script with nova-network option.

    % sudo ./deploy.sh allinone nova-network

You've done. Now you can access to Horizon with URL (http://${HOST_IP}/horizon).
with user : demo, pass : demo

How to use with 2 or more separated nodes (controller, compute) with nova-network
----

#### Preconfigured Architecure

                                       +-----------+
    +---------------+------------------| GW Router |-> The Internet
    |10.200.8.11    |10.200.8.12       +-----------+
    |eth0           |eth0
    +------------+  +------------+
    |            |  |            |
    | controller |  |  compute   |
    |            |  |            |
    +------------+  +------------+

fig.4 separated nodes with nova-network

#### OS Install

Please make disk partition such as /dev/sda6 on Controller node. Script make
this disk partition to use by Cinder.

#### Set up network interfaces

controller:/etc/network/interfaces

    controller% sudo vim /etc/network/interfaces
    auto lo
    iface lo inet loopback

    auto eth0
    iface eth0 inet static
            address 10.200.8.11
            netmask 255.255.255.0
            gateway 10.200.8.1
            dns-nameservers 8.8.8.8 8.8.4.4

compute:/etc/network/interfaces

    compute% sudo vim /etc/network/interfaces
    auto lo
    iface lo inet loopback

    auto eth0
    iface eth0 inet static
            address 10.200.8.12
            netmask 255.255.255.0
            gateway 10.200.8.1
            dns-nameservers 8.8.8.8 8.8.4.4

#### Clone scripts

Clone this scripts to your target node.

    controller% git clone https://github.com/jedipunkz/openstack_folsom_deploy.git
    controller% cd openstack_folsom_deploy

#### Edit Parameters

Set up parameters of deploy_with_nova-network.conf.

    BASE_DIR=`pwd`
    CONTROLLER_NODE_IP='10.200.8.11'
    COMPUTE_NODE_IP='10.200.8.12'
    
    MYSQL_PASS='secret'
    CINDER_VOLUME='/dev/sda6'
    
    FIXED_RANGE="10.0.0.0/24"
    FIXED_START_ADDR="10.0.0.2"
    FLOATING_RANGE="10.200.8.28/30"
    NETWORK_SIZE="256"
    
    OS_IMAGE_URL="https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img"
    OS_IMAGE_NAME="Cirros 0.3.0 x86_64"

#### Copy scripts

Copy these scripts to compute node.

    controller% scp -r openstack_folsom_deploy ${COMPUTE_NODE_IP}:~/

#### Run script

Run this scripts with nova-network option.

    controller% sudo ./deploy.sh controller nova-network
    compute   % sudo ./deploy.sh compute nova-network

Now you can access to Horizon with this URL http://${CONTROLLER_NODE_IP}/horizon

Using Metadata server with quantum
----

VM can get some informations from metadata server on controller node.
add a routing table to VM range network like this.

    controller% source ~/openstackrc # use admin user
    controller% quantum router-list  # get route-id
    controller% quantum port-list -- --device_id <router_id> --device_owner network:router_gateway # get router I/F addr
    controller% route add -net 172.24.17.0/24 gw <route_if_addr>

Using floating ip
----

If you want to use floating ip, do these operation.

    % source ~/openstackrc
    % quantum net-list
	% quantun floatingip-create <ext_net_id>
	% quantun floatingip-list
	% quantum port-list
	% quantum floatingip-associate <floatingip_id> <vm_port_id>

Datail of each parameters
----

<https://github.com/jedipunkz/openstack_folsom_deploy/blob/master/README_parameters.md>

Versions and Changelog
----

* 2012/11/01 : version 0.1 : First Release.
* 2012/11/08 : version 0.2 : Supported VLAN mode of quantum.
* 2012/12/03 : version 0.3 : Supported 3 nodes constitution (controller, network, compute nodes)
* 2012/12/07 : version 0.4 : Fixed a problem that can not access metadata server from VMs.
* 2013/01/09 : version 0.5 : supported nova-network
* 2013/01/17 : version 0.6 : fixed cinder problem. and make you do not need to exec create_network.
* 2013/02/20 : version 0.7 : enabled Public API to Public Network of Quantum

Known Issue
----

NONE
