#!/bin/bash
###################################################################################
# script install nova-compute and configure nova.conf                       	  #
# by EMR version 0.1 															  #
# à executer sur un node compute s'il n'est pas appelé par d'autres script        #
###################################################################################

servicename=nova-compute
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
memcached_servers="controller1:11211,controller2:11211,controller3:11211"

## installation et configuration des paquets en appelant le script nova-compute-conf.sh ##
echo "Début configuration des noeuds pour le service $servicename " >> $script_log
for node in $compute_nodelist;
do 
   ssh root@$node bash -c "'$configdir/$servicename/$servicename-conf.sh'" 
done
echo "Fin configuration des noeuds pour le service $servicename " >> $script_log

exit
