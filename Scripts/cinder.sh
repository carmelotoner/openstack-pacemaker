#!/bin/bash
###################################################################################
# script install neutron and configure cinder.conf 							      #
# by EMR version 0.1 															  #
# à executer sur un node controller s'il n'est pas appelé par d'autres script     #
###################################################################################
servicename=cinder
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
su -s /bin/sh -c "cinder-manage db sync" cinder
echo "Fin configuration des bases de données pour le service $servicename " >> $script_log

# create services in pacemaker
echo "Debut configuration des resources cluster pour le service $servicename " >> $script_log
echo "Ajout resource openstack-cinder-api dans le cluster " >> $script_log
pcs resource create openstack-cinder-api systemd:openstack-cinder-api --clone interleave=true
echo "Ajout resource openstack-cinder-scheduler dans le cluster " >> $script_log
pcs resource create openstack-cinder-scheduler systemd:openstack-cinder-scheduler --clone interleave=true

# Volume must be A/P for now. See https://bugzilla.redhat.com/show_bug.cgi?id=1193229
echo "Ajout resource openstack-cinder-volume dans le cluster " >> $script_log
pcs resource create openstack-cinder-volume systemd:openstack-cinder-volume
echo "Ajout des contraintes de services $servicename dans le cluster " >> $script_log
pcs constraint order start openstack-cinder-api-clone then openstack-cinder-scheduler-clone
pcs constraint colocation add openstack-cinder-scheduler-clone with openstack-cinder-api-clone
pcs constraint order start openstack-cinder-scheduler-clone then openstack-cinder-volume
pcs constraint colocation add openstack-cinder-volume with openstack-cinder-scheduler-clone
pcs constraint order start openstack-keystone-clone then openstack-cinder-api-clone

echo "Fin configuration des resources cluster pour le service $servicename " >> $script_log

exit
