#!/bin/bash
###################################################################################
# script install nova-compute and configure nova.conf                     	      #
# by EMR version 0.1 															  #
# à executer sur chaque node compute s'il n'est pas appelé par d'autres script    #
###################################################################################
timestamp() {
  date "+%Hh%M"
}

echo "Debut Opération  sur $nodename à $(timestamp)" >> $script_log

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

### installing package on all computes nodes ###
echo "Début installation des paquets pour le noeud $nodename" >> $script_log
   yum install openstack-nova-compute pacemaker-remote resource-agents pcs -y
echo "Fin installation des paquets pour le noeaud $nodename" >> $script_log

## configuring nova parameters on compute node ##
echo "Début configuration de nova.conf sur $nodename" >> $script_log
openstack-config --set /etc/nova/nova.conf DEFAULT enabled_apis osapi_compute,metadata
openstack-config --set /etc/nova/nova.conf DEFAULT transport_url rabbit://openstack:$admin_Pass@vip-rabbit
openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/nova/nova.conf DEFAULT my_ip $ip_Admin
openstack-config --set /etc/nova/nova.conf DEFAULT use_neutron True
openstack-config --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver

openstack-config --set /etc/nova/nova.conf vnc enabled True
openstack-config --set /etc/nova/nova.conf vnc vncserver_listen 0.0.0.0
openstack-config --set /etc/nova/nova.conf vnc vncserver_proxyclient_address $ip_Admin
openstack-config --set /etc/nova/nova.conf vnc novncproxy_base_url http://vip-nova:6080/vnc_auto.html

## conf pour glance ##
openstack-config --set /etc/nova/nova.conf glance api_servers http://vip-glance:9292

openstack-config --set /etc/nova/nova.conf oslo_concurrency lock_path /var/lib/nova/tmp

openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_uri http://vip-keystone:5000
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_url http://vip-keystone:35357
openstack-config --set /etc/nova/nova.conf keystone_authtoken memcached_servers $memcached_servers
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_type password
openstack-config --set /etc/nova/nova.conf keystone_authtoken project_domain_name Default
openstack-config --set /etc/nova/nova.conf keystone_authtoken user_domain_name Default
openstack-config --set /etc/nova/nova.conf keystone_authtoken project_name service
openstack-config --set /etc/nova/nova.conf keystone_authtoken username nova
openstack-config --set /etc/nova/nova.conf keystone_authtoken password $admin_Pass

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

## conf pour ceilometer ##
openstack-config --set /etc/nova/nova.conf DEFAULT instance_usage_audit True
openstack-config --set /etc/nova/nova.conf DEFAULT instance_usage_audit_period hour
openstack-config --set /etc/nova/nova.conf DEFAULT notify_on_state_change vm_and_task_state
openstack-config --set /etc/nova/nova.conf oslo_messaging_notifications driver messagingv2

echo "Fin configuration de nova.conf sur $nodename" >> $script_log

## Demarrage du service pacemaker_remote ##
systemctl enable pacemaker_remote.service 
systemctl start pacemaker_remote.service 

## Fin conf ##
echo "Fin Opération  sur $nodename à $(timestamp)" >> $script_log
	
exit
