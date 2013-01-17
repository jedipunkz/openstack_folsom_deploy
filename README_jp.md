OpenStack Folsom インストールスクリプト
=======================

OpenStack Folsom インストールスクリプト

作者
----

平井伴和 @jedipunkz

Twitter : <https://twitter.com/jedipunkz>
Blog    : <http://jedipunkz.github.com>

概要
----

Ubuntu Server 12.04 LTS もしくは Ubuntu Server 12.10 上で OpenStack Folsom を
構築するための bash スクリプトです。quantum もしくは nova-network を選択して構
築が出来ます。また、オールインワン (コミコミ構成) やコントローラノード・ネット
ワークノード・コンピュートノードの構成にて構築することも可能です。

バージョン 0.5 より nova-network に対応しました。

構成と注意点
----

このスクリプトは...

* nova-network を用いたオールインワン構成
* コントローラノード x 1 + コンピュートノード x N の分離型構成
* quantum を用いたオールインワン構成
* コントローラノード x 1 + ネットワークノード x 1 + コンピュートノード x N の分離側構成

にてテストしています。

各サービス (keystone, glance, nova, horizon, etc...) のそれぞれ毎に分離した構
成には対応していません。近い将来対応するかもしれません。興味ある方は仰ってくだ
さい。もしくは pull リクエストください。:D

モチベーション
----

devstack はとても便利で実際に私も使っています。quantum を理解するのにとても役
立ちました。ですが、幾つか不便なことろがあって再起動した際の作業が必要であった
り安定した環境を求めるには不十分でした。よって Ubuntu Cloud Archive もしくは
Ubuntu のパッケージを用いた構成を組む必要がありました。ソースアーカイブを git
clone しても構いませんでしたが、最近私は問題が無ければパッケージを使う派です。

quantum を用いた際の前提条件
----

1台もしくはそれ以上のノードが必要です。Ubuntu Server 12.04 LTS もしくは 12.10
が起動している必要があります。

分離側の場合、下記の図の通り 2 or 3 NIC を積んだノードが必要になります。eth0
はインターネットへの疎通を取るためのパブリックネットワーク用, eth1 は VM 間通
信のためのデータネットワーク用, eth2 は管理兼 API ネットワーク用です。

quantum は 4 つのネットワークを前提に設計されています。このスクリプトでは 3 ネッ
トワークで構築することを前提にしていますが、もし必要であれば4つにすることもで
きます。管理ネットワークと API ネットワークを兼務させ3つにしています。よって4
つにしたい場合は NIC を一つ挿すだけで構いません。

そしてコントローラノード (オールインワン構成の場合も) に Cinder 用のディスクデ
バイスを作る (挿す) 必要があります。例えば /dev/sda6 。ネットワークノードとコ
ンピュートノードには必要ありません。

図は手順の中で説明していきます。

nova-network を用いた前提構成
----

もしあなたが nova-network を選ぶならもっとシンプルな構成に出来ます。ノードには
1 NIC あれば良いでしょう。また Cinder のためのディスクデバイスはコントローラノー
ド(オールインワンの場合も) に必要になります。例えば /dev/sda6 等。


quantum を用いた手順
====

quantum を用いたオールインワン構成の構築方法
----

#### 構成

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

fig.1 quantum を用いたオールインワン構成

#### OS のインストール

Ubuntu 12.04 もしくは 12.10 をインストールしてください。この際に気をつけること
として /dev/sda6 等、swap, / (ルートパーティション) 以外のパーティションを作成
してください。Cinder サービスのために使います。

#### ネットワークインターフェースの設定

3つの NIC を積んだノードにて下記の通り設定を行います。

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

#### スクリプトの取得

ノード上にてこのスクリプトを取得します。

    % git clone https://github.com/jedipunkz/openstack_folsom_deploy.git
    % cd openstack_folsom_deploy

#### deploy_with_quantum.conf の修正

ディレクト上の deploy_with_quantum.conf ファイル内に必要なパラメータを記します。
ファイル内に説明を記しているので参考にしてください。

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

#### スクリプトの実行

スクリプトを実行してください。

	% sudo ./deploy.sh allinone quantum # wait some minutes...

完成です。この URL (http://${HOST_IP}/horizon) にアクセスし

* ユーザ : demo
* パスワード : demo

でログインしてください。VM の作成等が行えます。

quantum を用いた分離構成の構築方法
----

#### 前提構成

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
    |       public segment 10.200.8.0/24
    |
    | 10.200.8.1
    +-----------+
    | GW Router |-> The Internet
    +-----------+

fig.2 quantum を用いた分離構成

#### OS インストール

Ubuntu 12.04 もしくは 12.10 をインストールしてください。この際に気をつけること
としてコントローラノードのみ /dev/sda6 等、swap, / (ルートパーティション) 以外
のパーティションを作成してください。Cinder サービスのために使います。

#### スクリプトの取得

    controller% git clone https://github.com/jedipunkz/openstack_folsom_deploy.git

#### deploy_with_quantum.conf の修正

下記の通りパラメータを修正してください。

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

fig.1 の構成を前提にパラメータを修正しています。環境に合わせて設定してください。

#### スクリプトの転送

修正した deploy_with_quantum.conf と共々、ネットワークノード・コンピュー
トノードに転送してください。
    
    controller% scp -r openstack_folsom_deploy <network_node_ip>:~/
    controller% scp -r openstack_folsom_deploy <compute_node_ip>:~/

##### ネットワークインターフェースの設定

各ノード毎にネットワークインターフェースを設定してください。

コントローラノードは...

    auto lo
    iface lo inet loopback

    auto eth0
    iface eth0 inet static
        address 10.200.8.11
        netmask 255.255.255.0
        dns-nameservers 8.8.8.8 8.8.4.4
        dns-search cpi.ad.jp
    
    auto eth2
    iface eth2 inet static
        address 172.16.1.11
        netmask 255.255.255.0
        gateway 172.16.1.1

ネットワークノードは...

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

コンピュートノードは...

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

#### スクリプトの実行

各ノードでスクリプトを実行してください。第2引数に quantum オプションを付加して
ください。

    controller% sudo ./deploy.sh controller quantum
    network   % sudo ./deploy.sh network quantum
    compute   % sudo ./deploy.sh compute quntum
    
完成です。http://${CONTROLLER_NODE_IP}/horizon にアクセスして操作を行なってく
ださい。

* ユーザ : demo
* パスワード : demo

でログイン出来ます。

#### コンピュートノードの追加

コンピュートノードは追加することが出来ます。これにより仮想マシンリソースを増加
させることができます。下記の通り作業を行なってください。

    controller % scp -r openstack_folsom_deploy ${追加のコンピュートノード IP addr}:~/
    new_compute% cd openstack_folsom_deploy
    new_compute% vim deploy_with_nova-network.conf # ${COMPUTE_NODE_IP} の修正
    new_compute% sudo ./deploy.sh compute quantum


nova-network を用いた手順
====

nova-network を用いたオールインワン構成構築手順
----

オールインワン構成を組むための手順を記します。一番お手軽に試せる構成です。

#### 前提の構成

                                       +-----------+
    +----------------------------------| GW Router |-> The Internet
    |10.200.8.11                       +-----------+
    |eth0
    +------------+
    |            |
    | all in one |
    |            |
    +------------+

fig.3 nova-network を用いたオールインワン構成

#### OS インストール

Ubuntu 12.04 もしくは 12.10 をインストールしてください。この際に気をつけること
として /dev/sda6 等、swap, / (ルートパーティション) 以外のパーティションを作成
してください。Cinder サービスのために使います。

#### ネットワークインターフェースの設定

    % sudo vim /etc/network/interfaces
    auto lo
    iface lo inet loopback
    
    auto eth0
    iface eth0 inet static
            address 10.200.8.11
            netmask 255.255.255.0
            gateway 10.200.8.1
            dns-nameservers 8.8.8.8 8.8.4.4

#### スクリプトの取得

    % git clone https://github.com/jedipunkz/openstack_folsom_deploy.git
    % cd openstack_folsom_deploy

#### deploy_with_nova-network.conf の修正

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

#### スクリプトの実行

    % sudo ./deploy.sh allinone nova-network

完成です。URL http://${HOST_IP}/horizon にアクセスして操作を行なってください。

* ユーザ名 : demo
* パスワード : demo

でログイン出来ます。

nova-network を用いた分離構成の構築手順
----

コントローラノード x 1, コンピュートノード x N 構成の構築手順を記す。

#### 前提の構成

                                       +-----------+
    +---------------+------------------| GW Router |-> The Internet
    |10.200.8.11    |10.200.8.12       +-----------+
    |eth0           |eth0
    +------------+  +------------+
    |            |  |            |
    | controller |  |  compute   |
    |            |  |            |
    +------------+  +------------+

fig.4 nova-network を用いた分離構成

#### OS インストール

Ubuntu 12.04 もしくは 12.10 をインストールしてください。この際に気をつけること
としてコントローラノードのみ /dev/sda6 等、swap, / (ルートパーティション) 以外
のパーティションを作成してください。Cinder サービスのために使います。

#### ネットワークインターフェースの設定

コントローラノードは...

    controller% sudo vim /etc/network/interfaces
    auto lo
    iface lo inet loopback

    auto eth0
    iface eth0 inet static
            address 10.200.8.11
            netmask 255.255.255.0
            gateway 10.200.8.1
            dns-nameservers 8.8.8.8 8.8.4.4

コンピュートノードは...

    compute% sudo vim /etc/network/interfaces
    auto lo
    iface lo inet loopback

    auto eth0
    iface eth0 inet static
            address 10.200.8.12
            netmask 255.255.255.0
            gateway 10.200.8.1
            dns-nameservers 8.8.8.8 8.8.4.4

#### スクリプトの取得

    controller% git clone https://github.com/jedipunkz/openstack_folsom_deploy.git
    controller% cd openstack_folsom_deploy

#### deploy_with_nova-network.conf の修正

必要に応じてパラメータを設定してください。

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

#### スクリプトの転送

修正した deploy_with_nova-network.conf 共々、コンピュートノードに転送してくだ
さい。

    controller% scp -r openstack_folsom_deploy ${COMPUTE_NODE_IP}:~/

#### スクリプトの実行

スクリプトに下記の通り引数を与えて実行してください。

    controller% sudo ./deploy.sh controller nova-network
    compute   % sudo ./deploy.sh compute nova-network

完成です。URL  http://${CONTROLLER_NODE_IP}/horizon にアクセスして操作を行なっ
てください。

* ユーザ名 : demo
* パスワード : demo

でアクセス出来ます。

#### コンピュートノードの追加

コンピュートノードは追加することが出来ます。これにより仮想マシンリソースを増加
させることができます。下記の通り作業を行なってください。

    controller % scp -r openstack_folsom_deploy ${追加のコンピュートノード IP addr}:~/
    new_compute% cd openstack_folsom_deploy
    new_compute% vim deploy_with_nova-network.conf # ${COMPUTE_NODE_IP} の修正
    new_compute% sudo ./deploy.sh compute nova-network

メタデータサーバを使うために
----

VM は幾つかの情報をコントローラノード上のメタデータサーバを介して取得すること
が出来ます。SSH の公開鍵設置等をこのメタデータサーバを利用して配置することが出
来るので便利です。これにアクセスするためには下記の通り作業をコントローラノード
上で行ってください。

    controller% source ~/openstackrc # use admin user
    controller% quantum router-list  # get route-id
    controller% quantum port-list -- --device_id <router_id> --device_owner network:router_gateway # get router I/F addr
    controller% route add -net 172.24.17.0/24 gw <route_if_addr>

Floating IP の利用
----

もし Floating IP を使いたければ下記の通り作業を行なってください。folsom リリー
スの Horizon に問題があり下記の通りコマンドラインで実施する必要があります。

    % source ~/openstackrc
    % quantum net-list
	% quantun floatingip-create <ext_net_id>
	% quantun floatingip-list
	% quantum port-list
	% quantum floatingip-associate <floatingip_id> <vm_port_id>

その他、各パラメータの詳細
----

各パラメータの詳細については下記のドキュメントを参考にしてください。

<https://github.com/jedipunkz/openstack_folsom_deploy/blob/master/README_parameters_jp.md>

バージョン履歴
----

* 2012/11/01 : version 0.1 : First Release.
* 2012/11/08 : version 0.2 : Supported VLAN mode of quantum.
* 2012/12/03 : version 0.3 : Supported 3 nodes constitution (controller, network, compute nodes)
* 2012/12/07 : version 0.4 : Fixed a problem that can not access metadata server from VMs.
* 2013/01/09 : version 0.5 : support nova-network

Known Issue
----

特になし
