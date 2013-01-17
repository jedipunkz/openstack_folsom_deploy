nova-network 利用時のパラメータ説明
====

目的
----

nova-network 利用時の deploy_with_nova-network.conf 内パラメータについて解説し
ます。

#### BASE_DIR

カレントディレクトリです。下記の設定を変更しないでください。

    BASE_DIR=`pwd`

#### オールインワン構成の場合の IP アドレス指定

オールインワン構成利用時のホスト OS の IP アドレスです。オールインワン時には
NIC が一枚の設定を前提としています。その NIC に割り当てられている IP アドレス
を記してください。複数台構成の場合、設定を削除しても構いません。

例)

    HOST_IP='10.200.8.11'

#### 複数台構成の場合の IP アドレス指定

複数台構成 (Controller Node x 1 , Compute Node x N) を組みたい場合のホスト OS
の IP アドレス指定です。CONTROLLER_NODE_IP にはコントローラノードの IP アドレ
スを、COMPUTE_NODE_IP にはコンピュートノードの IP アドレスを指定してください。

    CONTROLLER_NODE_IP='172.16.1.11'
    COMPUTE_NODE_IP='172.16.1.13'
    

#### その他のパラメータ

MySQL の root ユーザパスワード MYSQL_PASS と Cinder に提供するディスクデバイス
名を CINDER_VOLUME として設定します。

    MYSQL_PASS='secret'
    CINDER_VOLUME='/dev/sda6'


#### Nova-network 関連パラメータ

Fixed Range をネットワークアドレスで指定するのが FIXED_RANGE です。

    FIXED_RANGE="10.0.0.0/24"

Fixed Range の開始アドレスを FIXED_START_ADDR で指定します。

    FIXED_START_ADDR="10.0.0.2"

Floating Range を FLOATING_RANGE で指定します。

    FLOATING_RANGE="10.200.8.28/30"

Fixed Range の IP アドレスの数を NETWORK_SIZE で指定します。/24 なら 256 とし
ておいてください。

    NETWORK_SIZE="256"



#### OS イメージ関連パラメータ

OS イメージの取得先 URL を OS_IMAGE_URL で指定します。

    OS_IMAGE_URL="https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img"

OS イメージの glance 登録名を OS_IMAGE_NAME で指定します。

    OS_IMAGE_NAME="Cirros 0.3.0 x86_64"


Quantum 利用時のパラメータ説明
====

目的
----

Quantum 利用時の deploy_with_quantum.conf 内パラメータについて解説し
ます。

#### BASE_DIR

カレントディレクトリです。下記の設定を変更しないでください。

    BASE_DIR=`pwd`

#### オールインワン構成の場合の IP アドレス指定

オールインワン構成利用時のホスト OS の IP アドレスです。オールインワン時には
NIC が3枚の設定を前提としています。Management ネットワーク用 NIC に割り当てら
れている IP アドレスを HOST_IP として。Public ネットワーク用 NIC に割り当てら
れている IP アドレスを HOST_PUB_IP として設定してください。

また、ノードの Data ネットワーク用 NIC を DATA_NIC、Public ネットワーク用 NIC
を PUBLIC_NIC として設定してください。

例)

    HOST_IP='172.16.1.11'
    HOST_PUB_IP='10.200.8.11
    DATA_NIC='eth1'
    PUBLIC_NIC='eth0'
    
#### 複数台構成の場合の IP アドレス指定

複数台構成 (Controller Node x 1 , Network Node x 1, Compute Node x N) を組みた
い場合のホスト OS の IP アドレス指定です。CONTROLLER_NODE_IP にはコントローラ
ノードの Management ネットワーク用 IP アドレスを、CONTROLLER_NODE_PUB_IP には
コントローラノードの Public ネットワーク用 IP アドレスを。NETWORK_NODE_IP には
ネットワークノードの Management ネットワーク用 IP アドレスを。COMPUTE_NODE_IP
にはコンピュートノードの Management ネットワーク用 IP アドレスを設定してくださ
い。また DATA_NIC_COMPUTE にはコンピュートノードの Data ネットワーク用 NIC の
デバイス名を指定してください。

また、ネットワークノードの Data ネットワーク用 NIC を DATA_NIC、Public ネット
ワーク用 NIC を PUBLIC_NIC として設定してください。

    CONTROLLER_NODE_IP='172.16.1.11'
    CONTROLLER_NODE_PUB_IP='10.200.8.16'
    NETWORK_NODE_IP='172.16.1.12'
    COMPUTE_NODE_IP='172.16.1.13'
    DATA_NIC_COMPUTE='eth1'
    DATA_NIC='eth1'
    PUBLIC_NIC='eth0'

下記の構成を前提に上記の例を記しました。

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
    

#### その他のパラメータ

MySQL の root ユーザパスワード MYSQL_PASS と Cinder に提供するディスクデバイス
名を CINDER_VOLUME として設定します。また Data ネットワーク用 NIC デバイス名を
DATA_NIC として、Public ネットワーク用 NIC デバイス名を


    MYSQL_PASS='secret'
    CINDER_VOLUME='/dev/sda6'

#### Quantum 関連パラメータ

VLAN モードの場合 'vlan'、GRE トンネルモードの場合 'gre' として NETWORK_TYPE
を設定してください。

    NETWORK_TYPE='gre'

QUANTUM に作成する内部ネットワークのゲートウェイアドレスを INT_NET_GATEWAY

    INT_NET_GATEWAY='172.24.17.254'

Quantum に作成する内部ネットワークのネットワークアドレスを INT_NET_RANGE

    INT_NET_RANGE='172.24.17.0/24'

外部ネットワークのゲートウェイを EXT_NET_GATEWAY 

    EXT_NET_GATEWAY='10.200.8.1'

外部ネットワークの開始アドレス、終了アドレスをそれぞれ下記の通り

    EXT_NET_START='10.200.8.36'
    EXT_NET_END='10.200.8.40'

外部ネットワークのネットワークアドレスを

    EXT_NET_RANGE='10.200.8.0/24'

として設定してください。

#### OS イメージ関連パラメータ

OS イメージの取得先 URL を OS_IMAGE_URL で指定します。

    OS_IMAGE_URL="https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img"

OS イメージの glance 登録名を OS_IMAGE_NAME で指定します。

    OS_IMAGE_NAME="Cirros 0.3.0 x86_64"

