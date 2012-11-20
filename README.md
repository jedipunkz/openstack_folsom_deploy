OpenStack Folsom Bootstrap Script
=======================

OpenStack Folsom Bootstrap Script for Ubuntu Server

Author
----
Tomokazu Hirai @jedipunkz

Notice
----

This script code was tested only for all in one installation and additional compuote installation. Now I am
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

You need 1 or more node(s) with Ubuntu Server 12.04 LTS / 12.10.

You should have a machine with 3 NICs. eth0 is public network interface. eth1
is VM (data) network interface, this will be used for communication to other
VMs on other compute nodes. eth2 is completely for management.

Quantum was designed based on 4 networks, public/data/management/api. This script
designed based on 3 networks (if you want 4 networks, you can do it with this).
public/data/management & api. All of APIs will be listening on management networks
interface.

        management segment 172.16.1.0/24                                                                                                                                             
        +--------------------------------------------                                                                                                                                
        | eth2 172.16.1.11                           eth2 172.16.1.12                                                                                                                
        +------------+                               +-----------+                                                                                                                   
        |            | eth1 ------------------- eth1 |           |                                                                                                                   
        | controller | vlan/gre seg = 172.24.17.0/24 | compute01 | ..> adding                                                                                                        
        |            | data segment = 172.16.2.0/24  |           |                                                                                                                   
        +------------+ 172.16.2.11       172.16.2.12 +-----------+                                                                                                                   
        | eth0                                       eth0                                                                                                                            
        |                                            +--------+                                                                                                                      
        +--------------------------------------------| Router |--> The Internet                                                                                                      
                public segment 10.200.8.0/24         +--------+ 


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
        address 172.26.2.11
        netmask 255.255.255.0
    
    auto eth2
    iface eth2 inet static
        address 172.16.1.11
        netmask 255.255.255.0
        gateway 172.16.1.1
        dns-nameservers 8.8.8.8 8.8.4.4

You can install and manage openstack via eth2 NiC. When you run this script,
openvswitch will adding eth0 and eth1 for bridge interfaces.

and Especialy you need to have a disk device for cinder such as /dev/sda6.

How to use
----

get script to your target.

    % git clone https://github.com/jedipunkz/openstack_folsom_deploy.git
    % cd openstack_folsom_deploy

Update these environment in deploy.conf

    # for all in one (controller)
    HOST_IP='172.16.1.11'
    # for separated nodes (in near future, I support these parameters)
    NOVA_IP='172.16.1.11'
    KEYSTONE_IP='172.16.1.11'
    GLANCE_IP='172.16.1.11'
    CINDER_IP='172.16.1.11'
    DB_IP='172.16.1.11'
    QUANTUM_IP='172.16.1.11'
    RABBIT_IP='172.16.1.11'
    # etc env
    MYSQL_PASS='secret'
    CINDER_VOLUME='/dev/sda6'
    DATA_NIC='eth1'
    PUBLIC_NIC='eth0'
    # network_type : gre or vlan
    NETWORK_TYPE='vlan'
    # additional compute (compute)
    ADD_NOVA_IP='172.16.1.12'
    DATA_NIC_COMPUTE='eth1'
    
    # quantun env
    INT_NET_GATEWAY='172.24.17.254'
    INT_NET_RANGE='172.24.17.0/24'
    EXT_NET_GATEWAY='10.200.8.1'
    EXT_NET_START='10.200.8.36'
    EXT_NET_END='10.200.8.40'
    EXT_NET_RANGE='10.200.8.0/24'

Run this script.

	% sudo ./deploy.sh controller

That's all and You've done :D

Now you can create and boot VMs on Horizon (http://${HOST_IP}/horizon)  with user: demo, pass: demo.

#### Additional Compute Node

If you have a plan to build additinal compute nodes, please run deploy.sh with 'compute' option.
parameters of deploy.conf must be same as controller's one.

    % scp -r <controller_ip>:~/openstack_folsom_deploy .
	% cd openstack_folsom_deploy
	% sudo ./deploy.sh compute

check your nova status with this command :

    % sudo nova-manage service list
    Binary           Host                                 Zone             Status     State Updated_At
    nova-cert        opst-folsom01                        nova             enabled    :-)   2012-11-02 10:10:07
    nova-consoleauth opst-folsom01                        nova             enabled    :-)   2012-11-02 10:10:07
    nova-compute     opst-folsom01                        nova             enabled    :-)   2012-11-02 10:10:13
    nova-scheduler   opst-folsom01                        nova             enabled    :-)   2012-11-02 10:10:07
    nova-compute     opst-folsom02                        nova             enabled    :-)   2012-11-02 10:10:16

Need more compute node(s) ? you can do it.

    % scp -r <controller_ip>:~/openstack_folsom_deploy .
	% cd openstack_folsom_deploy
    % vim deploy.conf # update $ADD_NOVA_IP
	% sudo ./deploy.sh compute

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
