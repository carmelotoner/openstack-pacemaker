#!/bin/bash
###################################################################################
# script install neutron and configure neutron.conf 							  #
# by EMR version 0.1 															  #
# à executer sur un node controller s'il n'est pas appelé par d'autres script     #
###################################################################################
servicename=neutron
nodename=`hostname |sed 's/.ftoma.mg*//'`
network_Admin=10.101.0
network_Stor=10.102.0
nfs_server=$network_Stor.10
ip_Admin=`ifconfig | grep "$network_Admin" |awk -F " " '{print $2}'`
admin_Pass=dksdhDnci12h
demo_Pass=demo
configdir=/srv/openstack/config ## /srv/openstack est un point de montage nfs monté sur tous les noeuds ##
controller_nodelist="controller1 controller2 controller3"
compute_nodelist="compute1 compute2"
all_nodelist=$controller_nodelist" "$compute_nodelist
script_log=$configdir/$servicename/$servicename-install.log  
service="keystone glance cinder nova neutron ceilometer horizon heat"
memcached_servers="controller1:11211,controller2:11211,controller3:11211"

## installation et configuration des paquets sur les controlleurs en appelant le script neutron-conf.sh ##
echo "Debut configuration des noeuds pour le service $servicename " >> $script_log
for node in $controller_nodelist;
do 
   ssh root@$node bash -c "'$configdir/$servicename/$servicename-conf.sh'" 
done
echo "Fin configuration des noeuds pour le service $servicename " >> $script_log

## installation et configuration des paquets sur les computes en appelant le script neutron-compute-conf.sh ##
echo "Debut configuration des noeuds pour le service $servicename " >> $script_log
for node in $compute_nodelist;
do 
   ssh root@$node bash -c "'$configdir/$servicename/$servicename-compute-conf.sh'" 
done
echo "Fin configuration des noeuds pour le service $servicename " >> $script_log

## initialisation des base nova et nova_api ##
echo "Début configuration de base de données pour le service $servicename " >> $script_log
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
echo "Fin configuration de base de données pour le service $servicename " >> $script_log

## initialisation du service avant le cluster ##
systemctl start neutron-server
systemctl stop neutron-server

# add the neutron server service to pacemaker
echo "Ajout du service neutron-server dans le cluster " >> $script_log
pcs resource create neutron-server systemd:neutron-server op start timeout=90 --clone interleave=true
pcs constraint order start openstack-keystone-clone then neutron-server-clone
echo "Fin Ajout du service neutron-server dans le cluster " >> $script_log

# add the neutron agents services to pacemaker
echo "Ajout des services neutron-agents dans le cluster " >> $script_log
#pcs resource create neutron-scale ocf:neutron:NeutronScale --clone globally-unique=true clone-max=3 interleave=true

#pcs resource create neutron-ovs-cleanup ocf:neutron:OVSCleanup --clone interleave=true
pcs resource create neutron-netns-cleanup ocf:neutron:NetnsCleanup --clone interleave=true
pcs resource create neutron-linuxbridge-agent  systemd:neutron-linuxbridge-agent  --clone interleave=true
pcs resource create neutron-dhcp-agent systemd:neutron-dhcp-agent --clone interleave=true
#pcs resource create neutron-l3-agent systemd:neutron-l3-agent --clone interleave=true
pcs resource create neutron-metadata-agent systemd:neutron-metadata-agent  --clone interleave=true

echo "Ajout des contraintes de services neutron-agents dans le cluster " >> $script_log
#pcs constraint order start neutron-scale-clone then neutron-ovs-cleanup-clone
#pcs constraint colocation add neutron-ovs-cleanup-clone with neutron-scale-clone
#pcs constraint order start neutron-ovs-cleanup-clone then neutron-netns-cleanup-clone
#pcs constraint colocation add neutron-netns-cleanup-clone with neutron-ovs-cleanup-clone
pcs constraint order start neutron-netns-cleanup-clone then neutron-linuxbridge-agent-clone
pcs constraint colocation add neutron-linuxbridge-agent-clone with neutron-netns-cleanup-clone
pcs constraint order start neutron-linuxbridge-agent-clone then neutron-dhcp-agent-clone
pcs constraint colocation add neutron-dhcp-agent-clone with neutron-linuxbridge-agent-clone
#pcs constraint order start neutron-dhcp-agent-clone then neutron-l3-agent-clone
#pcs constraint colocation add neutron-l3-agent-clone with neutron-dhcp-agent-clone
#pcs constraint order start neutron-l3-agent-clone then neutron-metadata-agent-clone
pcs constraint order start neutron-dhcp-agent-clone then neutron-metadata-agent-clone
pcs constraint colocation add neutron-metadata-agent-clone with neutron-dhcp-agent-clone

pcs constraint order start neutron-server-clone then neutron-netns-cleanup-clone
echo "Fin Ajout des services neutron-agents dans le cluster " >> $script_log

echo "Fin configuration du service neutron-server dans le cluster " >> $script_log

exit
