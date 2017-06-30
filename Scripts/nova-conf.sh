#!/bin/bash
###################################################################################
# script install glance and configure glance-api.conf & glance-registry.conf 	  #
# by EMR version 0.1 															  #
# à executer sur chaque node controller s'il n'est pas appelé par d'autres script #
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
script_log=$configdir/$servicename/$servicename-install.log  
service="keystone glance cinder nova neutron ceilometer horizon heat"
memcached_servers="controller1:11211,controller2:11211,controller3:11211"

### recup time ###
timestamp() {
  date "+%Hh%M"
}

echo "Debut Opération sur $nodename à $(timestamp)" >> $script_log


### installing package on all controller nodes ###
echo "Début installation des paquets pour le noeaud $nodename"
yum install openstack-nova-api openstack-nova-conductor \
  openstack-nova-console openstack-nova-novncproxy \
  openstack-nova-scheduler -y
echo "Fin installation des paquets pour le noeaud $nodename"

## configuring nova parameters on controller nodes ##
echo "Début configuration de nova.conf sur $nodename" >> $script_log
openstack-config --set /etc/nova/nova.conf DEFAULT enabled_apis osapi_compute,metadata
openstack-config --set /etc/nova/nova.conf DEFAULT transport_url rabbit://openstack:$admin_Pass@vip-rabbit
openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/nova/nova.conf DEFAULT my_ip $ip_Admin
openstack-config --set /etc/nova/nova.conf DEFAULT use_neutron True
openstack-config --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver

openstack-config --set /etc/nova/nova.conf vnc vncserver_listen $ip_Admin
openstack-config --set /etc/nova/nova.conf vnc vncserver_proxyclient_address $ip_Admin

openstack-config --set /etc/nova/nova.conf glance api_servers http://vip-glance:9292

openstack-config --set /etc/nova/nova.conf oslo_concurrency lock_path /var/lib/nova/tmp

openstack-config --set /etc/nova/nova.conf api_database connection = mysql+pymysql://nova:$admin_Pass@vip-mysql/nova_api
openstack-config --set /etc/nova/nova.conf database connection = mysql+pymysql://nova:$admin_Pass@vip-mysql/nova

openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_uri http://vip-keystone:5000
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_url http://vip-keystone:35357
openstack-config --set /etc/nova/nova.conf keystone_authtoken memcached_servers $memcached_servers
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_type password
openstack-config --set /etc/nova/nova.conf keystone_authtoken project_domain_name Default
openstack-config --set /etc/nova/nova.conf keystone_authtoken user_domain_name Default
openstack-config --set /etc/nova/nova.conf keystone_authtoken project_name service
openstack-config --set /etc/nova/nova.conf keystone_authtoken username nova
openstack-config --set /etc/nova/nova.conf keystone_authtoken password $admin_Pass

openstack-config --set /etc/nova/nova.conf DEFAULT scheduler_host_subset_size 30
openstack-config --set /etc/nova/api-paste.ini filter:authtoken auth_host vip-keystone
openstack-config --set /etc/nova/api-paste.ini filter:authtoken project_domain_name Default
openstack-config --set /etc/nova/api-paste.ini filter:authtoken user_domain_name Default
openstack-config --set /etc/nova/api-paste.ini filter:authtoken project_name service
openstack-config --set /etc/nova/api-paste.ini filter:authtoken username nova
openstack-config --set /etc/nova/api-paste.ini filter:authtoken password $admin_Pass

## configuring neutron parameters for nova compute service ##
openstack-config --set /etc/nova/nova.conf neutron url http://vip-neutron:9696
openstack-config --set /etc/nova/nova.conf neutron auth_url http://vip-keystone:35357
openstack-config --set /etc/nova/nova.conf neutron auth_type password
openstack-config --set /etc/nova/nova.conf neutron project_domain_name Default
openstack-config --set /etc/nova/nova.conf neutron user_domain_name Default
openstack-config --set /etc/nova/nova.conf neutron region_name RegionOne
openstack-config --set /etc/nova/nova.conf neutron project_name service
openstack-config --set /etc/nova/nova.conf neutron username neutron
openstack-config --set /etc/nova/nova.conf neutron password $admin_Pass
openstack-config --set /etc/nova/nova.conf neutron service_metadata_proxy True
openstack-config --set /etc/nova/nova.conf neutron metadata_proxy_shared_secret $admin_Pass

## configuring cinder parameters for nova compute service api ##
openstack-config --set /etc/nova/nova.conf cinder os_region_name RegionOne

echo "Fin configuration de nova.conf sur $nodename" >> $script_log


## Fin conf ##
echo "Fin Opération  sur $nodename à $(timestamp)" >> $script_log

exit
