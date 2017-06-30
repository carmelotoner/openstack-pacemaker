#!/bin/bash
###################################################################################
# script install neutron and configure neutron ml2 .conf 						  #
# by EMR version 0.1 															  #
# à executer sur chaque node controller s'il n'est pas appelé par d'autres script #
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

timestamp() {
  date "+%Hh%M"
}

echo "Debut Opération  sur $nodename à $(timestamp)" >> $script_log

### installing package on all controllers nodes ###
echo "Début installation des paquets pour le noeud $nodename" >> $script_log
 yum install openstack-cinder -y
echo "Fin installation des paquets pour le noeaud $nodename" >> $script_log

## configuring cinder parameters on controller nodes ##
echo "Début configuration de cinder.conf sur $nodename" >> $script_log
openstack-config --set /etc/cinder/cinder.conf database connection mysql+pymysql://cinder:$admin_Pass@vip-mysql/cinder

openstack-config --set /etc/cinder/cinder.conf DEFAULT transport_url rabbit://openstack:$admin_Pass@vip-rabbit
openstack-config --set /etc/cinder/cinder.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/cinder/cinder.conf DEFAULT my_ip $ip_Admin

openstack-config --set /etc/cinder/cinder.conf keystone_authtoken auth_uri http://vip-keystone:5000
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken auth_url http://vip-keystone:35357
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken memcached_servers $memcached_servers
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken auth_type password
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken project_domain_name Default
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken user_domain_name Default
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken project_name service
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken username cinder
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken password $admin_Pass
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken auth_uri http://vip-keystone:5000

openstack-config --set /etc/cinder/cinder.conf DEFAULT glance_host vip-glance
openstack-config --set /etc/cinder/cinder.conf DEFAULT memcache_servers $memcache_servers

openstack-config --set /etc/cinder/cinder.conf DEFAULT nfs_shares_config /etc/cinder/nfs_exports
openstack-config --set /etc/cinder/cinder.conf DEFAULT nfs_sparsed_volumes true
openstack-config --set /etc/cinder/cinder.conf DEFAULT nfs_mount_options v3

openstack-config --set /etc/cinder/cinder.conf DEFAULT volume_driver cinder.volume.drivers.nfs.NfsDriver

openstack-config --set /etc/cinder/cinder.conf oslo_concurrency lock_path /var/lib/cinder/tmp
echo "Fin configuration de cinder.conf sur $nodename" >> $script_log

## configuration du NFS ##
echo "Configuration du backend NFS"
cat > /etc/cinder/nfs_exports << EOF
$nfs_server:$configdir/cinder
EOF

chown root:cinder /etc/cinder/nfs_exports
chmod 0640 /etc/cinder/nfs_exports

## Fin conf ##
echo "Fin Opération  sur $nodename à $(timestamp)" >> $script_log
	
exit
