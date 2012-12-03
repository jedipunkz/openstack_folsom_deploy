OpenStack Folsom Bootstrap Script
=======================

OpenStack Folsom Bootstrap Script for Ubuntu Server

Author
----
Tomokazu Hirai @jedipunkz

Twitter : <https://twitter.com/jedipunkz>
Blog    : <http://jedipunkz.github.com>

Notice
----

This script was tested 'all in one mode' and '3 nodes mode (controller, network, compute).
Now I'm developing for separated compornent nodes mode. Please wait a moment :D or
feel FREE for your fork.

Motivation
----

devstack is very usefull for me. I am using devstack for understanding
openstack and especially Quantum ! ;) but when I reboot devstack node, all of
openstack compornents was not booted. That is not good for me. and I wanted to
use Ubuntu Cloud Archive packages.

Premise Environment
----

You need 1 or more node(s) with Ubuntu Server 12.04 LTS / 12.10.

You should have a machine with 3 NICs. eth0 is public network interface. eth1
is VM (data) network interface, this will be used for communication to other
VMs on other compute nodes. eth2 is completely for management.

Quantum was designed based on 4 networks, public/data/management/api. This script
designed based on 3 networks (if you want 4 networks, you can do it with this).
public/data/management & api. All of APIs will be listening on management networks
interface.

    management segment 172.16.1.0/24
    +--------------------------------------------+------------------+-----------------
    |                                            |                  |
    |                                            |                  |
    | eth2 172.16.1.11                           | eth2 172.16.1.12 | eth2 172.24.1.13
    +------------+                               +-----------+      +-----------+
    |            | eth1 ------------------- eth1 |           |      |           |
    | controller | vlan/gre seg = 172.24.17.0/24 |  compute  |      |  network  |
    |    node    | data segment = 172.16.2.0/24  |   node    |      |   node    |
    +------------+ 172.16.2.11       172.16.2.12 +-----------+      +-----------+      
    | eth0 10.200.8.11                           | eth0 10.200.8.12 | eth0 10.200.8.13
    |                                            |                  |
    |                                            |                  |
    +--------------------------------------------+------------------+-----------------
    |       public segment 10.200.8.0/24
    |
    | 10.200.8.1
    +-----------+
    | GW Router |-> The Internet
    +-----------+

so you should setup each NICs like this. this is /etc/network/interface


You can install and manage openstack via eth2 NiC. When you run this script,
openvswitch will adding eth0 and eth1 for bridge interfaces.

    auto lo
    iface lo inet loopback

    auto eth0
    iface eth0 inet static
        up ifconfig $IFACE 0.0.0.0 up
        down ifconfig $IFACE down
        address 10.200.8.11
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

and Especialy you need to have a disk device for cinder such as /dev/sda6.

How to use (all in one mode)
----

get script to your target.

    % git clone https://github.com/jedipunkz/openstack_folsom_deploy.git
    % cd openstack_folsom_deploy

Update these environment in deploy.conf

    # for all in one mode
    HOST_IP='172.16.1.11'
    # controller node
    CONTROLLER_NODE_IP='172.16.1.11'
    # network node
    NETWORK_NODE_IP='172.16.1.13'
    # compute node
    COMPUTE_NODE_IP='172.16.1.12'
    DATA_NIC_COMPUTE='eth1'
    # etc env
    MYSQL_PASS='secret'
    CINDER_VOLUME='/dev/sda6'
    DATA_NIC='eth1'
    PUBLIC_NIC='eth0'
    # network_type : gre or vlan
    NETWORK_TYPE='gre'
    
    # quantun env
    INT_NET_GATEWAY='172.24.17.254'
    INT_NET_RANGE='172.24.17.0/24'
    EXT_NET_GATEWAY='10.200.8.1'
    EXT_NET_START='10.200.8.36'
    EXT_NET_END='10.200.8.40'
    EXT_NET_RANGE='10.200.8.0/24'

Run this script.

	% sudo ./deploy.sh allinone

That's all and You've done :D

Now you can create and boot VMs on Horizon (http://${HOST_IP}/horizon)  with user: demo, pass: demo.

How to user : 3 nodes (controller, network, compute) mode
----

If you have a plan to build separated by function (controller, network,
compute nodes), please run deploy.sh with 'controller', 'network', 'compute' option.
Parameters of deploy.conf must be same as controller's one.

    controller% git clone https://github.com/jedipunkz/openstack_folsom_deploy.git

update parameters of deploy.conf.

    # for all in one mode
    HOST_IP='172.16.1.11'
    # controller node
    CONTROLLER_NODE_IP='172.16.1.11'
    # network node
    NETWORK_NODE_IP='172.16.1.13'
    # compute node
    COMPUTE_NODE_IP='172.16.1.12'
    DATA_NIC_COMPUTE='eth1'
    # etc env
    MYSQL_PASS='secret'
    CINDER_VOLUME='/dev/sda6'
    DATA_NIC='eth1'
    PUBLIC_NIC='eth0'
    # network_type : gre or vlan
    NETWORK_TYPE='gre'
    
    # quantun env
    INT_NET_GATEWAY='172.24.17.254'
    INT_NET_RANGE='172.24.17.0/24'
    EXT_NET_GATEWAY='10.200.8.1'
    EXT_NET_START='10.200.8.36'
    EXT_NET_END='10.200.8.40'
    EXT_NET_RANGE='10.200.8.0/24'

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
        up ifconfig $IFACE 0.0.0.0 up
        down ifconfig $IFACE down
        address 10.200.8.11
        netmask 255.255.255.0
        dns-nameservers 8.8.8.8 8.8.4.4
        dns-search cpi.ad.jp
    
    auto eth2
    iface eth2 inet static
        address 172.16.1.11
        netmask 255.255.255.0
        gateway 172.16.1.1

Network Node's /etc/network/interfaces

    auto lo
    iface lo inet loopback
    
    auto eth0
    iface eth0 inet static
        up ifconfig $IFACE 0.0.0.0 up
        up ip link set $IFACE promisc on
        down ip link set $IFACE promisc off
        down ifconfig $IFACE down
        address 10.200.8.21
        netmask 255.255.255.0
        #gateway 10.200.8.1
        # dns-* options are implemented by the resolvconf package, if installed
        dns-nameservers 8.8.8.8 8.8.4.4
        dns-search cpi.ad.jp
    
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

Compoute Node's /etc/network/interfaces

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

Deploy OpenStack for each compornent.

    controller% sudo ./deploy.sh controller
    network   % sudo ./deploy.sh network
    compute   % sudo ./deploy.sh compute
    
at last, create network on controller node.

    controller% sudo ./deploy.sh create_network

You've done. Please access http://${CONTROLLER_NODE_IP}/horizon via your
browser. and create some vm instances. :D


Using floating ip
----

If you want to use floating ip, do these operation.

    % source ~/openstackrc
    % quantum net-list
	% quantun floatingip-create <ext_net_id>
	% quantun floatingip-list
	% quantum port-list
	% quantum floatingip-associate <floatingip_id> <vm_port_id>

Enabling to access to VMs
----

If you want to access to VMs from anyware, do these operation.

    % source $HOME/openstackrc
	% nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
	% nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
	% nova secgroup-list-rules default

Versions and Changelog
----

* 2012/11/01 : version 0.1 : First Release.
* 2012/11/08 : version 0.2 : Supported VLAN mode of quantum.
* 2012/12/03 : version 0.3 : Supported 3 nodes constitution (controller, network, compute nodes)

Known Issue
----

* can not access to the metadata server from your virtual machines.
