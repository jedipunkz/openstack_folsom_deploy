OpenStack Folsom Deploy Script
=======================

OpenStack Folsom (2012.2) bootstrap script for Ubuntu Server 12.04 LTS.

Author
----
Tomokazu Hirai @jedipunkz

Notice
----

This script code was tested only for all in one installation. Now I am
developing for separated compornent nodes, and addtitional compute nodes.
Please wait a moment :D or Feel FREE for your fork.

Motivation
----

devstack is very usefull for me. I am using devstack for understanding
openstack and especially Quantum ! ;) but when I reboot devstack node, all of
openstack compornents was not booted. That is not good for me. and I wanted to
use Ubuntu Cloud Archive packages.

Premise Environment
----

You should have a machine with 3 NICs. eth0 is public network interface. eth1
is VM (data) network interface, this will be used for communication to other
VMs on other compute nodes. eth2 is completely for management.

fixed_range is not same as VM (data) segment. so If you want use GRE Tunneling
for each VMs communication, these segments must not be same.


            management segment 192.168.0.0/24
    +-------------------------------------------
    | eth2 192.168.0.8
    +------------+
    |            | eth1
    | controller | fixed_range = 172.24.17.0/24
    |            | data segment = 172.26.0.0/24
    +------------+
    | eth0                                      +--------+
    +-------------------------------------------| Router |--> The Internet
            public segment 10.200.8.0/24        +--------+

so you should setup each NICs like this. this is /etc/network/interface

    # The loopback network interface
    auto lo
    iface lo inet loopback
    
    auto eth0
    iface eth0 inet static
        up ifconfig $IFACE 0.0.0.0 up
        down ifconfig $IFACE down
        address 10.200.8.10
        netmask 255.255.255.0
        dns-nameservers 8.8.8.8
        dns-search cpi.ad.jp
    
    auto eth1
    iface eth1 inet static
        address 172.26.0.110
        netmask 255.255.255.0
    
    auto eth2
    iface eth2 inet static
        address 192.168.0.8
        netmask 255.255.255.0
        gateway 192.168.0.1
        dns-nameservers 8.8.8.8 8.8.4.4

You can install and manage openstack via eth2 NiC. When you run this script,
openvswitch will adding eth0 and eth1 for bridge interfaces.

and Especialy you need to have a disk device for cinder such as /dev/sda6.

How to use
----

Update these environment on deploy.conf.

    # for all in one
    HOST_IP='192.168.0.8'
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

Meaning of these parameters are ...

$HOST_IP         : Target Host's IP addr (all in one)
$MYSQL_PASS      : MySQL's root password
$CINDER_VOLUME   : disk device name for cinder
$DATA_NIC        : name of NIC for VM (Data) Segment
$PUBLIC_NIC      : name of NIC for Public Segment
$INT_NET_GATEWAY : Quantum's internal network's gateway
$INT_NET_RANGE   : Quantum's internal network's range
$EXT_NET_GATEWAY : Quantum's external network's gateway
$EXT_NET_START   : Quantum's external network's starting addr
$EXT_NET_END     : Quantum's external network's ending addr
$EXT_NET_RANGE   : Quantum's external network's range

Run this script.

    % git clone https://github.com/jedipunkz/openstack_folsom_deploy.git
	% cd openstack_folsom_deploy
	% ./deploy.sh allinone

That's all. :D

Now you can create and boot VMs on Horizon (http://${HOST_IP}/horizon) .

Using floating ip
----

If you want to use floating ip, do these operation.

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
