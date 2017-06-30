#!/bin/bash
###################################################################################
# script install heat and configure heat.conf 							      #
# by EMR version 0.1 															  #
# à executer sur un node controller s'il n'est pas appelé par d'autres script     #
###################################################################################
servicename=ceilometer
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

## initialisation de la base mongo ##
echo "Initialisation de la base mongodb pour le service $servicename " >> $script_log
mongo --host controller1 --eval '
  db = db.getSiblingDB("ceilometer");
  db.createUser({user: "ceilometer",
  pwd: "$admin_Pass",
  roles: [ "readWrite", "dbAdmin" ]})'

  MongoDB shell version: 2.6.x
  connecting to: controller:27017/test
  Successfully added user: { "user" : "ceilometer", "roles" : [ "readWrite", "dbAdmin" ] }
  
## installation et configuration des paquets en appelant le script ceilometer-compute-conf.sh ##
echo "Debut configuration des noeuds $compute_nodelist pour le service $servicename" >> $script_log
for node in $compute_nodelist;
do 
   ssh root@$node bash -c "'$configdir/$servicename/$servicename-compute-conf.sh'" 
done
echo "Fin configuration des noeuds $compute_nodelist pour le service $servicename" >> $script_log


## installation et configuration des paquets en appelant le script ceilometer-compute-conf.sh ##
echo "Debut configuration des noeuds $controller_nodelist pour le service $servicename" >> $script_log
for node in $compute_nodelist;
do 
   ssh root@$node bash -c "'$configdir/$servicename/$servicename-conf.sh'" 
done
echo "Fin configuration des noeuds $compute_nodelist pour le service $servicename" >> $script_log


## creation des resources cluster ceilometer ##
echo "Creation de la resource redis " >> $script_log
pcs resource create redis redis wait_last_known_master=true --master meta notify=true ordered=true interleave=true
echo "Creation de la resource vip-redis " >> $script_log
pcs resource create vip-redis IPaddr2 ip=$network_Admin.10
echo "Creation de la resource openstack-ceilometer-central" >> $script_log
pcs resource create openstack-ceilometer-central systemd:openstack-ceilometer-central --clone interleave=true
echo "Creation de la resource openstack-ceilometer-collector" >> $script_log
pcs resource create openstack-ceilometer-collector systemd:openstack-ceilometer-collector --clone interleave=true
echo "Creation de la resource openstack-ceilometer-api" >> $script_log
pcs resource create openstack-ceilometer-api systemd:openstack-ceilometer-api --clone interleave=true
echo "Creation de la resource delay" >> $script_log
pcs resource create delay Delay startdelay=10 --clone interleave=true
#pcs resource create openstack-ceilometer-alarm-evaluator systemd:openstack-ceilometer-alarm-evaluator --clone interleave=true
#pcs resource create openstack-ceilometer-alarm-notifier systemd:openstack-ceilometer-alarm-notifier --clone interleave=true
echo "Creation de la resource delay" >> $script_log
pcs resource create openstack-ceilometer-notification systemd:openstack-ceilometer-notification  --clone interleave=true
echo "Ajouts des contraintes pour les services " >> $script_log
pcs constraint order promote redis-master then start vip-redis
pcs constraint colocation add vip-redis with master redis-master
pcs constraint order start vip-redis then openstack-ceilometer-central-clone kind=Optional
pcs constraint order start openstack-ceilometer-central-clone then openstack-ceilometer-collector-clone
pcs constraint order start openstack-ceilometer-collector-clone then openstack-ceilometer-api-clone
pcs constraint colocation add openstack-ceilometer-api-clone with openstack-ceilometer-collector-clone
pcs constraint order start openstack-ceilometer-api-clone then delay-clone
pcs constraint colocation add delay-clone with openstack-ceilometer-api-clone
pcs constraint order start delay-clone then openstack-ceilometer-notification-clone
pcs constraint colocation add openstack-ceilometer-notification-clone with delay-clone

pcs constraint order start mongod-clone then openstack-ceilometer-central-clone
pcs constraint order start httpd-clone then openstack-ceilometer-central-clone

echo "Fin de la configuration des services $servicename " >> $script_log

exit

