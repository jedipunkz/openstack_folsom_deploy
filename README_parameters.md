Configuration with nova-network
====

This document explain the meaning of each parameters of
deploy_with_nova-network.conf file.

#### BASE_DIR

Current Directory's path. Do not edit this parameter.

    BASE_DIR=`pwd`

#### parameters in all in one mode 

in all in one mode, set IP address of Host OS to ${HOST_IP} parameter.

    HOST_IP='10.200.8.11'

#### parameters in sepalated nodes mode

in sepalated nodes mode (Controller Node x 1 , Compute Node x N), set IP
adddress of Controller node to ${CONTROLLER_NODE_IP} , set IP addoress of
Compute node to ${COMPUTE_NODE_IP}.

    CONTROLLER_NODE_IP='172.16.1.11'
    COMPUTE_NODE_IP='172.16.1.13'

#### misc parameters

'root' user's password of MySQL.

    MYSQL_PASS='secret'

Disk device name of Cinder.

    CINDER_VOLUME='/dev/sda6'


#### Nova-network 関連パラメータ

Network address of fixed range network.

    FIXED_RANGE="10.0.0.0/24"

Starting IP address of fixed range network.

    FIXED_START_ADDR="10.0.0.2"

Network address of floating range network.

    FLOATING_RANGE="10.200.8.28/30"

Number of IP addresses in fixed range network.

    NETWORK_SIZE="256"


#### OS Image parameters

URL which this script get OS image.

    OS_IMAGE_URL="https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img"

OS Image Name.

    OS_IMAGE_NAME="Cirros 0.3.0 x86_64"


Parameters with Quantum
====

This document explain meaning of each parameters of deploy_with_quantum.conf file.


#### BASE_DIR

Carrent directory's path, do no edit this parameter

    BASE_DIR=`pwd`

#### parameters in all in one mode

in all in one mode, set Management IP address of Host OS to ${HOST_IP}, set
Public IP address of Host OS to ${HOST_PUB_IP}. and set NIC device name of
data network to ${DATA_NIC}, set NIC device name of public network to
${PUBLIC_NIC} .
and 

    HOST_IP='172.16.1.11'
    HOST_PUB_IP='10.200.8.11
    DATA_NIC='eth1'
    PUBLIC_NIC='eth0'
    
#### paramaters in separated nodes mode

in separated nodes mode (Controller Node x 1 , Network Node x 1, Compute Node
x N).

set managemement IP address of controller node to ${CONTROLLER_NODE_IP}.

    CONTROLLER_NODE_IP='172.16.1.11'

set public IP address of controller node to ${CONTROLLER_NODE_PUB_IP}.

    CONTROLLER_NODE_PUB_IP='10.200.8.16'

set management IP address of network node to ${NETWORK_NODE_IP}.

    NETWORK_NODE_IP='172.16.1.12'

set management IP address of compute node to ${COMPUTE_NODE_IP}.

    COMPUTE_NODE_IP='172.16.1.13'

set compute node's NIC device name of data network to ${DATA_NIC_COMPUTE}.

    DATA_NIC_COMPUTE='eth1'

set network node's NIC device name of data network to ${DATA_NIC}.

    DATA_NIC='eth1'

set network node's NIC device name of public network to ${PUBLIC_NIC}.

    PUBLIC_NIC='eth0'

These paramaters was setuped assuming the figure below.

    management segment 172.16.1.0/24
    +--------------------------------------------+------------------+-----------------
    |                                            |                  |
    |                                            |                  |
    | eth2 172.16.1.12                           | eth2 172.16.1.13 | eth2 172.16.1.11
    +------------+                               +-----------+      +------------+
    |            | eth1 ------------------- eth1 |           |      |            |
    |  network   | vlan/gre seg = 172.24.17.0/24 |  compute  |      | controller |
    |    node    | data segment = 172.16.2.0/24  |   node    |      |    node    |
    +------------+ 172.16.2.12       172.16.2.13 +-----------+      +------------+
    | eth0 10.200.8.12                                              | eth0 10.200.8.11
    |                                                               |
    |                                                               |
    +--------------------------------------------+------------------+-----------------
public segment 10.200.8.0/24
    

#### misc parameters

'root' user's password of MySQL.

    MYSQL_PASS='secret'
    
Disk device name of Cinder.
    
    CINDER_VOLUME='/dev/sda6'

#### paraeters in quantum

specify network mode, 'vlan' or 'gre'

    NETWORK_TYPE='gre'

Gateway address of internal network.

    INT_NET_GATEWAY='172.24.17.254'

Network address of internal network.

    INT_NET_RANGE='172.24.17.0/24'

Starting address and Ending address of internal network.

    EXT_NET_START='10.200.8.36'
    EXT_NET_END='10.200.8.40'

Netwok address of external network.

    EXT_NET_GATEWAY='10.200.8.1'

Gateway address of external network.

    EXT_NET_RANGE='10.200.8.0/24'

#### OS Image parameters

URL which this script get OS image.

    OS_IMAGE_URL="https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img"
    
OS Image Name.
    
    OS_IMAGE_NAME="Cirros 0.3.0 x86_64"
