# dockwall 
# docker based VNF for Contrail Service Chaining
firewall nfv docker image

Dockwall uses a modified nova docker driver to enable docker images to act as OpenContrail Service Instances.
The main modification is the addition of two routing tables inside the Container allowing for two default routes
and one for the right Virtual Network. ip rules will forward any traffic ingressing on one to the other interface.
Additionally the DHCP client in the Container will add the default routes to the correct routing tables.

Start with a standard OpenContrail installation with at least one Compute Node. A Compute Node will be dedicated to host Docker Containers. It cannot server any KVM based VMs anymore!
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

