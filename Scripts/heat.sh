#!/bin/bash
###################################################################################
# script install heat and configure heat.conf 							      #
# by EMR version 0.1 															  #
# à executer sur un node controller s'il n'est pas appelé par d'autres script     #
###################################################################################
servicename=heat
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

## installation et configuration des paquets en appelant le script cinder-conf.sh ##
echo "Debut configuration des noeuds pour le service $servicename " >> $script_log
for node in $controller_nodelist;
do 
   ssh root@$node bash -c "'$configdir/$servicename/$servicename-conf.sh'" 
done
echo "Fin configuration des noeuds pour le service $servicename " >> $script_log

## initialisation de base cinder ##
echo "Début configuration de base de données pour le service $servicename " >> $script_log
 su -s /bin/sh -c "heat-manage db_sync" heat
echo "Fin configuration des bases de données pour le service $servicename " >> $script_log

## creations des resources et contraintes cluster pour le servic heat ##
echo "Début configuration cluster pour le service $servicename " >> $script_log
echo "Creation de la resource openstack-heat-api " >> $script_log
pcs resource create openstack-heat-api systemd:openstack-heat-api --clone interleave=true
echo "Creation de la resource openstack-heat-api-cfn " >> $script_log
pcs resource create openstack-heat-api-cfn systemd:openstack-heat-api-cfn  --clone interleave=true
#pcs resource create openstack-heat-api-cloudwatch systemd:openstack-heat-api-cloudwatch --clone interleave=true
echo "Creation de la resource openstack-heat-engine " >> $script_log
pcs resource create openstack-heat-engine systemd:openstack-heat-engine --clone interleave=true
echo "Ajout des contraintes de resource pour le service heat" >> $script_log
pcs constraint order start openstack-heat-api-clone then openstack-heat-api-cfn-clone
pcs constraint colocation add openstack-heat-api-cfn-clone with openstack-heat-api-clone
pcs constraint order start openstack-heat-api-cfn-clone then openstack-heat-engine-clone
pcs constraint colocation add openstack-heat-engine-clone with openstack-heat-api-cfn-clone
pcs constraint order start openstack-ceilometer-notification-clone then openstack-heat-api-clone
echo "Fin configuration cluster pour le service $servicename " >> $script_log

exit
