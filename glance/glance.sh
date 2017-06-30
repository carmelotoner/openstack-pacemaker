#!/bin/bash
###################################################################################
# script install Glance and configure glance.conf 							      #
# by EMR version 0.1 															  #
# à executer sur un node controller s'il n'est pas appelé par d'autres script     #
###################################################################################
servicename=glance
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
script_log=$configdir/$servicename/$servicename-install.log  
service="keystone glance cinder nova neutron ceilometer horizon heat"

## installation et configuration des paquets en appelant le script keystone_conf.sh ##
echo "Debut configuration des noeuds pour le service $servicename " >> $script_log
for node in $controller_nodelist;
do 
   ssh root@$node bash -c "'$configdir/$servicename/$servicename-conf.sh'" 
done
echo "Fin configuration des noeuds pour le service $servicename " >> $script_log

## creation des resources NFS glances au niveau cluster pour le stockage des images ##
echo "Creation du NFS pour le stockage des images glance" >> $script_log
pcs resource create openstack-glance-fs Filesystem device="$nfs_server:$configdir/glance" directory="/var/lib/glance" fstype="nfs" options="v3" --clone

# wait for glance-fs to be started and running
sleep 5

# Make sure it's writable
chown glance:nobody /var/lib/glance

## initialisation de la base glance ##
echo "initialisation de la base $glance" >> $script_log
su -s /bin/sh -c "glance-manage db_sync" glance

## creation des resources cluster glances ##
echo "Creation de la resource openstack-glance-registry" >> $script_log
pcs resource create openstack-glance-registry systemd:openstack-glance-registry --clone interleave=true
echo "Creation de la resource openstack-glance-api" >> $script_log
pcs resource create openstack-glance-api systemd:openstack-glance-api --clone interleave=true
echo "Ajout des contraintes pour les service glance" >> $script_log
pcs constraint order start openstack-glance-fs-clone then openstack-glance-registry-clone
pcs constraint colocation add openstack-glance-registry-clone with openstack-glance-fs-clone
pcs constraint order start openstack-glance-registry-clone then openstack-glance-api-clone
pcs constraint colocation add openstack-glance-api-clone with openstack-glance-registry-clone

pcs constraint order start openstack-keystone-clone then openstack-glance-registry-clone

echo "Fin configuration Glance" >> $script_log

exit



