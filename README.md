# dockwall 
# docker based VNF for Contrail Service Chaining
firewall nfv docker image

Dockwall uses a modified nova docker driver to enable docker images to act as OpenContrail Service Instances.
The main modification is the addition of two routing tables inside the Container allowing for two default routes
and one for the right Virtual Network. ip rules will forward any traffic ingressing on one to the other interface.
Additionally the DHCP client in the Container will add the default routes to the correct routing tables.

