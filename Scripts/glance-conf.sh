#!/bin/bash
###################################################################################
# script install glance and configure glance-api.conf & glance-registry.conf 	  #
# by EMR version 0.1 															  #
# à executer sur chaque node controller s'il n'est pas appelé par d'autres script #
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
memcached_servers="prcontroller1:11211,prcontroller2:11211,prcontroller3:11211"
timestamp() {
  date "+%Hh%M"
}

echo "Debut Opération  sur $nodename à $(timestamp)" >> $script_log

### installing package on all controller nodes ###
echo "Debut installation du paquet openstack-glance effectuée" >> $script_log
yum install openstack-glance -y
echo "installation du paquet openstack-glance effectuée" >> $script_log

## configuring glance parameters on controller node ##
echo "Début configuration de glance-api.conf sur $nodename" >> $script_log

openstack-config --set /etc/glance/glance-api.conf database connection mysql+pymysql://glance:$admin_Pass@vip-mysql/glance
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_uri http://vip-keystone:5000
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_url http://vip-keystone:35357
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken memcached_servers $memcached_servers
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_type password
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken project_domain_name Default
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken user_domain_name Default
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken project_name service
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken username $servicename
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken password $admin_Pass
openstack-config --set /etc/glance/glance-api.conf paste_deploy flavor keystone

openstack-config --set /etc/glance/glance-api.conf glance_store stores file,http
openstack-config --set /etc/glance/glance-api.conf glance_store default_store file
openstack-config --set /etc/glance/glance-api.conf glance_store filesystem_store_datadir /var/lib/glance/images/
echo "Fin configuration de glance-api.conf sur $nodename" >> $script_log
echo "Début configuration de glance-registry.conf sur $nodename" >> $script_log
openstack-config --set /etc/glance/glance-registry.conf database connection mysql+pymysql://glance:$admin_Pass@vip-mysql/glance
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_uri http://vip-keystone:5000
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_url http://vip-keystone:35357
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken memcached_servers $memcached_servers
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_type password
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken project_domain_name Default
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken user_domain_name Default
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken project_name service
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken username $servicename
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken password $admin_Pass
openstack-config --set /etc/glance/glance-registry.conf paste_deploy flavor keystone
echo "Fin configuration de glance-registry.conf sur $nodename" >> $script_log

## Fin conf ##
echo "Fin Opération  sur $nodename à $(timestamp)" >> $script_log

exit




