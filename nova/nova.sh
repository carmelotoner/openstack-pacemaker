#!/bin/bash
###################################################################################
# script install Glance and configure glance.conf 							      #
# by EMR version 0.1 															  #
# à executer sur un node controller s'il n'est pas appelé par d'autres script     #
###################################################################################
servicename=nova
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

## installation et configuration des paquets en appelant le script nova-conf.sh ##
echo "Debut configuration des noeuds pour le service $servicename " >> $script_log
for node in $controller_nodelist;
do 
   ssh root@$node bash -c "'$configdir/$servicename/$servicename-conf.sh'" 
done
echo "Fin configuration des noeuds pour le service $servicename " >> $script_log

## initialisation des base nova et nova_api ##
echo "Debut configuration des bases de données pour le service $servicename " >> $script_log
su -s /bin/sh -c "nova-manage api_db sync" nova
su -s /bin/sh -c "nova-manage db sync" nova
echo "Fin configuration des bases de données pour le service $servicename " >> $script_log

## creation des resources nova dans le cluster ##
echo "Configuration des services $servicename dans le cluster " >> $script_log

pcs resource create openstack-nova-consoleauth systemd:openstack-nova-consoleauth --clone interleave=true
echo "Configuration du service openstack-nova-consoleauth dans le cluster effectuée " >> $script_log
pcs resource create openstack-nova-novncproxy systemd:openstack-nova-novncproxy --clone interleave=true
echo "Configuration du service openstack-nova-novncproxy dans le cluster effectuée " >> $script_log
pcs resource create openstack-nova-api systemd:openstack-nova-api --clone interleave=true
echo "Configuration du service openstack-nova-api dans le cluster effectuée " >> $script_log
pcs resource create openstack-nova-scheduler systemd:openstack-nova-scheduler --clone interleave=true
echo "Configuration du service openstack-nova-scheduler dans le cluster effectuée " >> $script_log
pcs resource create openstack-nova-conductor systemd:openstack-nova-conductor --clone interleave=true
echo "Configuration du service openstack-nova-conductor dans le cluster effectuée " >> $script_log

pcs constraint order start openstack-nova-consoleauth-clone then openstack-nova-novncproxy-clone
pcs constraint colocation add openstack-nova-novncproxy-clone with openstack-nova-consoleauth-clone

pcs constraint order start openstack-nova-novncproxy-clone then openstack-nova-api-clone
pcs constraint colocation add openstack-nova-api-clone with openstack-nova-novncproxy-clone

pcs constraint order start openstack-nova-api-clone then openstack-nova-scheduler-clone
pcs constraint colocation add openstack-nova-scheduler-clone with openstack-nova-api-clone

pcs constraint order start openstack-nova-scheduler-clone then openstack-nova-conductor-clone
pcs constraint colocation add openstack-nova-conductor-clone with openstack-nova-scheduler-clone

pcs constraint order start openstack-keystone-clone then openstack-nova-consoleauth-clone
echo "Ajout des contraintes de services dans le cluster effectuée " >> $script_log
echo "Configuration des services $servicename dans le cluster terminée " >> $script_log


###################################################################################
# Debut ajout des noeuds compute  pour remotekey				                  #
# by EMR version 0.1 															  #
# à executer un controller s'il n'est pas appelé par d'autres script 			  #
###################################################################################

### Preparation pour la reception des noeuds compute ###
echo "generation de la clé authentication pacemaker_remoted" >> $script_log
dd if=/dev/urandom of=$configdir/$servicename/authkey bs=4096 count=1
remotekey=$configdir/$servicename/authkey

## copie de la clé sur tous les noeauds ##
echo "Copie des clé sur tous les noeuds" >> $script_log
for node in $all_nodelist;
do 
   ssh root@$node 'mkdir -p /etc/pacemaker/'
   scp $remotekey root@$node:/etc/pacemaker/
   echo "Copie de la clé sur le noeud $node" >> $script_log
done
echo "Fin copie des la clé sur tous les noeuds pour le service $servicename " >> $script_log


exit
