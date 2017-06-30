#!/bin/bash
###################################################################################
# script install heat and configure heat.conf 							          #
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

timestamp() {
  date "+%Hh%M"
}

echo "Debut Opération  sur $nodename à $(timestamp)" >> $script_log

### installing package on all controllers nodes ###
echo "Début installation des paquets pour le noeud $nodename" >> $script_log
yum install openstack-heat-api openstack-heat-api-cfn openstack-heat-engine -y
echo "Fin installation des paquets pour le noeaud $nodename" >> $script_log

### configuring package on all controllers nodes ###
openstack-config --set /etc/heat/heat.conf database connection mysql+pymysql://heat:$admin_Pass@vip-mysql/heat
openstack-config --set /etc/heat/heat.conf DEFAULT transport_url rabbit://openstack:$admin_Pass@vip-rabbit
openstack-config --set /etc/heat/heat.conf DEFAULT memcache_servers $memcached_servers

openstack-config --set /etc/heat/heat.conf DEFAULT heat_metadata_server_url http://vip-heat:8000
openstack-config --set /etc/heat/heat.conf DEFAULT heat_waitcondition_server_url http://vip-heat:8000/v1/waitcondition
openstack-config --set /etc/heat/heat.conf DEFAULT stack_domain_admin heat_domain_admin
openstack-config --set /etc/heat/heat.conf DEFAULT stack_domain_admin_password $admin_Pass
openstack-config --set /etc/heat/heat.conf DEFAULT stack_user_domain_name heat

openstack-config --set /etc/heat/heat.conf keystone_authtoken auth_uri http://vip-keystone:5000
openstack-config --set /etc/heat/heat.conf keystone_authtoken auth_url  http://vip-keystone:35357
openstack-config --set /etc/heat/heat.conf keystone_authtoken memcached_servers  controller1:11211,controller2:11211,controller3:11211
openstack-config --set /etc/heat/heat.conf keystone_authtoken auth_type  password
openstack-config --set /etc/heat/heat.conf keystone_authtoken project_domain_name default
openstack-config --set /etc/heat/heat.conf keystone_authtoken user_domain_name  default
openstack-config --set /etc/heat/heat.conf keystone_authtoken project_name service
openstack-config --set /etc/heat/heat.conf keystone_authtoken username heat
openstack-config --set /etc/heat/heat.conf keystone_authtoken password  $admin_Pass

openstack-config --set /etc/heat/heat.conf trustee auth_type password
openstack-config --set /etc/heat/heat.conf trustee auth_url http://vip-keystone:35357
openstack-config --set /etc/heat/heat.conf trustee username heat
openstack-config --set /etc/heat/heat.conf trustee password $admin_Pass
openstack-config --set /etc/heat/heat.conf trustee user_domain_name default

openstack-config --set /etc/heat/heat.conf clients_keystone auth_uri http://vip-keystone:35357

openstack-config --set /etc/heat/heat.conf ec2authtoken auth_uri http://vip-keystone:5000

# disable CWLiteAlarm that is incompatible with A/A
openstack-config --set /etc/heat/heat.conf DEFAULT enable_cloud_watch_lite false

## Fin conf ##
echo "Fin Opération  sur $nodename à $(timestamp)" >> $script_log

exit
