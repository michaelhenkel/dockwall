# dockwall
docker based VNF for Contrail Service Chaining

Dockwall uses a modified nova docker driver to enable docker images to act as OpenContrail Service Instances.
The main modification is the addition of two routing tables inside the Container allowing for two default routes
and one for the right Virtual Network. ip rules will forward any traffic ingressing on one to the other interface.
Additionally the DHCP client in the Container will add the default routes to the correct routing tables.

The following installation has been done on a Ubuntu 14.04 server with OpenContrail 2.10.

Start with a standard OpenContrail installation with at least one Compute Node. A Compute Node will be dedicated for hosting Docker Containers. It cannot serve any KVM based VMs anymore!
Best thing is to create an Aggregation Zone and add the Compute Node to it.

On the Controller source the OpenStack credentials, create Aggregate and add Compute Node to it:
```
source /etc/contrail/openstackrc
nova aggregate-create docker docker
nova aggregate-add-host docker computedocker
```
and modify /etc/glance/glance-api.conf for adding Docker Container support:

```
 # Supported values for the 'container_format' image attribute
-#container_formats=ami,ari,aki,bare,ovf
+container_formats=ami,ari,aki,bare,ovf,docker
```
and restart the Glance service:
```
service glance-api restart
```

<b>A. Quick Start</b>

On the Docker Compute Node

1.. Install Docker
```
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9
echo "deb https://get.docker.io/ubuntu docker main" | sudo tee -a /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install lxc-docker
```

2.. get Dockerfile for building a minimal network/firewall enabled image
```
git clone http://github.com/michaelhenkel/dockwall
cd dockwall
build -t dockwall .
cd..
```

3.. get openstack authentication and source it
```
scp root@Controller:/etc/contrail/openstackrc /etc/contrail
source /etc/contrail/openstackrc
```

4.. save docker image to glance
```
docker save dockwall | glance image-create --name dockwall --container-format=docker --disk-format=raw --is-public True
```

5.. some additional packages
```
apt-get install python-stdeb python-oslo.serialization python-dev
easy_install pip
pip install docker-py --upgrade
```

6.. install oslo.concurrency
```
wget https://pypi.python.org/packages/source/o/oslo.concurrency/oslo.concurrency-1.8.0.tar.gz#md5=ec2774ab12c0e3c14b21cab52d047951
tar zxvvf oslo.concurrency-1.8.0.tar.gz
cd oslo.concurrency-1.8.0/
python setup.py --command-packages=stdeb.command sdist_dsc
cd deb_dist/oslo-concurrency-1.8.0/
dpkg-buildpackage -rfakeroot -uc -us
cd ..
dpkg -i python-oslo.concurrency_1.8.0-1_all.deb
cd
```

7.. install oslo.context	   
```
wget https://pypi.python.org/packages/source/o/oslo.context/oslo.context-0.2.0.tar.gz#md5=f6ae1896dab2c77ad016e35cd7c4a20d
tar zxvf oslo.context-0.2.0.tar.gz
cd oslo.context-0.2.0/
python setup.py --command-packages=stdeb.command sdist_dsc
cd deb_dist/oslo-context-0.2.0/
dpkg-buildpackage -rfakeroot -uc -us
cd ..
dpkg -i python-oslo.context_0.2.0-1_all.deb
cd
```

8.. install oslo.log	  
```
wget https://pypi.python.org/packages/source/o/oslo.log/oslo.log-1.0.0.tar.gz#md5=37f5dc8642e9bee93ec2897333f0152d
tar zxvf oslo.log-1.0.0.tar.gz
cd oslo.log-1.0.0/
python setup.py --command-packages=stdeb.command sdist_dsc
cd deb_dist/oslo-log-1.0.0/
dpkg-buildpackage -rfakeroot -uc -us
cd ..
dpkg -i python-oslo.log_1.0.0-1_all.deb
cd
```

9.. install patched nova-docker	  
```
git clone -b stable/juno http://github.com/michaelhenkel/nova-docker
cd nova-docker
cp etc/nova/rootwrap.d/docker.filters /etc/nova/rootwrap.d/
python setup.py --command-packages=stdeb.command sdist_dsc
cd deb_dist/nova-docker-2d0409a/
dpkg-buildpackage -rfakeroot -uc -us
cd ..
dpkg -i python-nova-docker_2d0409a-1_all.deb
cd
usermod -G libvirtd,docker nova
```

10.. fix oslo_/oslo. confusion	  
```
ln -s /usr/lib/python2.7/dist-packages/oslo/config /usr/lib/python2.7/dist-packages/oslo_config
ln -s /usr/lib/python2.7/dist-packages/oslo/utils /usr/lib/python2.7/dist-packages/oslo_utils
ln -s /usr/lib/python2.7/dist-packages/oslo/i18n /usr/lib/python2.7/dist-packages/oslo_i18n
ln -s /usr/lib/python2.7/dist-packages/oslo/serialization /usr/lib/python2.7/dist-packages/oslo_serialization
```

11.. enable nova docker	   
On compute node, update /etc/nova/nova-compute.conf to set Nova driver and Docker VIF driver. Remove everything else.
```
[DEFAULT]
compute_driver = novadocker.virt.docker.DockerDriver
[docker]
vif_driver = novadocker.virt.docker.opencontrail.OpenContrailVIFDriver
```

12.. restart nova-compute  
```
service nova-compute restart
```

In OpenContrail you now need to define a new Service Template using the dockwall image and activating aggregation zones.
Define three interfaces in the Service Template: 1. Left, 2. Right, 3. Mgmt.
Create the three Virtual Networks as usual and define the Service Instance using the new Service Template.
Final part is to define the Network Policy using the created Service Instance and assign it to the Left and Right Virtual Network. The dockwall image will now start forwarding traffic from Left to Right VN. 

In order to see the Container network configuration you can create open a shell and look around:

```
root@computedocker2:~# docker ps
CONTAINER ID        IMAGE               COMMAND                CREATED             STATUS              PORTS               NAMES
c8a4500c8df9        dockwall:latest     "/usr/bin/supervisor   2 hours ago         Up About an hour                        nova-e0e79594-3f00-498f-be42-96f770b8acbd
root@computedocker2:~# docker exec -it c8a4500c8df9 bash
root@instance-00000073:/# ip addr sh
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
10: ns108d91c4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 02:10:8d:91:c4:61 brd ff:ff:ff:ff:ff:ff
    inet 10.0.0.40/24 brd 10.0.0.255 scope global ns108d91c4
       valid_lft forever preferred_lft forever
    inet6 fe80::10:8dff:fe91:c461/64 scope link
       valid_lft forever preferred_lft forever
12: ns26a4d19b: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 02:26:a4:d1:9b:b1 brd ff:ff:ff:ff:ff:ff
    inet 10.0.1.40/24 brd 10.0.1.255 scope global ns26a4d19b
       valid_lft forever preferred_lft forever
    inet6 fe80::26:a4ff:fed1:9bb1/64 scope link
       valid_lft forever preferred_lft forever
14: ns7aa01d4f: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 02:7a:a0:1d:4f:70 brd ff:ff:ff:ff:ff:ff
    inet 172.16.0.36/24 brd 172.16.0.255 scope global ns7aa01d4f
       valid_lft forever preferred_lft forever
    inet6 fe80::7a:a0ff:fe1d:4f70/64 scope link
       valid_lft forever preferred_lft forever
 ```
As you can see all three interface have IP addresses assigned. Now looking into the routing table
```
root@instance-00000073:/# ip route sh
default via 172.16.0.1 dev ns7aa01d4f
10.0.0.0/24 dev ns108d91c4  proto kernel  scope link  src 10.0.0.40
10.0.1.0/24 dev ns26a4d19b  proto kernel  scope link  src 10.0.1.40
172.16.0.0/24 dev ns7aa01d4f  proto kernel  scope link  src 172.16.0.36
```
shows only a default route for the management network. But this is expected as the Left and Right networks use dedicated routing tables:
```
root@instance-00000073:/# ip route sh table ns108d91c4
default via 10.0.0.1 dev ns108d91c4
10.0.0.0/24 dev ns108d91c4  scope link  src 10.0.0.40

root@instance-00000073:/# ip route sh table ns26a4d19b
default via 10.0.1.1 dev ns26a4d19b
10.0.1.0/24 dev ns26a4d19b  scope link  src 10.0.1.40
```
The ip rules show that every traffic hitting the Left interface is automatically using the Right routing table and every traffic coming from/to the Right interface uses the Left RT:
```
root@instance-00000073:/# ip rule show
0:      from all lookup local
32764:  from all iif ns26a4d19b lookup ns108d91c4
32765:  from all iif ns108d91c4 lookup ns26a4d19b
32766:  from all lookup main
32767:  from all lookup default
```
This is necessary for being able to operate with multiple default routes. With only one routing table we only can have one default route which in turn means that we would have to either maintain static routes or use a dynamic routing protocol for the network not having the default route set. With the ip rules we don't need that.
A tcpdump in the Container shows traffic passing through the two interfaces:
```
root@instance-00000073:/# tcpdump -nS -i ns108d91c4
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on ns108d91c4, link-type EN10MB (Ethernet), capture size 65535 bytes
18:34:43.317632 IP 10.0.5.11 > 8.8.8.8: ICMP echo request, id 1262, seq 1, length 64
18:34:43.334266 IP 8.8.8.8 > 10.0.5.11: ICMP echo reply, id 1262, seq 1, length 64
18:34:44.318498 IP 10.0.5.11 > 8.8.8.8: ICMP echo request, id 1262, seq 2, length 64
18:34:44.334192 IP 8.8.8.8 > 10.0.5.11: ICMP echo reply, id 1262, seq 2, length 64
18:34:45.320002 IP 10.0.5.11 > 8.8.8.8: ICMP echo request, id 1262, seq 3, length 64
18:34:45.334824 IP 8.8.8.8 > 10.0.5.11: ICMP echo reply, id 1262, seq 3, length 64
18:34:46.322272 IP 10.0.5.11 > 8.8.8.8: ICMP echo request, id 1262, seq 4, length 64
18:34:46.337264 IP 8.8.8.8 > 10.0.5.11: ICMP echo reply, id 1262, seq 4, length 64
18:34:47.323129 IP 10.0.5.11 > 8.8.8.8: ICMP echo request, id 1262, seq 5, length 64
18:34:47.336617 IP 8.8.8.8 > 10.0.5.11: ICMP echo reply, id 1262, seq 5, length 64

root@instance-00000073:/# tcpdump -nS -i ns26a4d19b
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on ns26a4d19b, link-type EN10MB (Ethernet), capture size 65535 bytes
18:35:49.985408 IP 10.0.5.11 > 8.8.8.8: ICMP echo request, id 1263, seq 1, length 64
18:35:50.005283 IP 8.8.8.8 > 10.0.5.11: ICMP echo reply, id 1263, seq 1, length 64
18:35:50.985357 IP 10.0.5.11 > 8.8.8.8: ICMP echo request, id 1263, seq 2, length 64
18:35:51.001919 IP 8.8.8.8 > 10.0.5.11: ICMP echo reply, id 1263, seq 2, length 64
18:35:51.985594 IP 10.0.5.11 > 8.8.8.8: ICMP echo request, id 1263, seq 3, length 64
18:35:52.003780 IP 8.8.8.8 > 10.0.5.11: ICMP echo reply, id 1263, seq 3, length 64
18:35:53.020874 IP 10.0.5.11 > 8.8.8.8: ICMP echo request, id 1263, seq 4, length 64
18:35:53.033497 IP 8.8.8.8 > 10.0.5.11: ICMP echo reply, id 1263, seq 4, length 64
18:35:53.988427 IP 10.0.5.11 > 8.8.8.8: ICMP echo request, id 1263, seq 5, length 64
18:35:54.000848 IP 8.8.8.8 > 10.0.5.11: ICMP echo reply, id 1263, seq 5, length 64
```
Note that source and destination networks are not directly attached to the container and that 
there is no static route configured. Both default routes work.
