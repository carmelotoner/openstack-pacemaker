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
mongodb_servers="controller1:27017,controller2:27017,controller3:27017"

timestamp() {
  date "+%Hh%M"
}
echo "Début Opération  sur $nodename à $(timestamp)" >> $script_log

### installing package on all controllers nodes ###
echo "Début installation des paquets pour le noeud $nodename" >> $script_log
 yum install openstack-ceilometer-compute -y
echo "Fin installation des paquets pour le noeud $nodename" >> $script_log

### configuring package on all controllers nodes ###
echo "Configuration des paquets pour le noeud $nodename" >> $script_log
openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT transport_url rabbit://openstack:$admin_Pass@vip-rabbit
openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT auth_strategy keystone

openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_uri http://vip-keystone:5000
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_url http://vip-keystone:35357
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken memcached_servers $memcached_servers
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_type password
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken project_domain_name default
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken user_domain_name default
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken project_name service
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken username ceilometer
openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken password $admin_Pass

openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials auth_url = http://vip-keystone:5000
openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials project_domain_id default
openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials user_domain_id default
openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials auth_type password
openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials username ceilometer
openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials project_name service
openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials password CEILOMETER_PASS
openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials interface internalURL
openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials region_name RegionOne

echo "Fin Opération  sur $nodename à $(timestamp)" >> $script_log

exit