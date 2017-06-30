#!/bin/bash
###################################################################################
# script install neutron and configure neutron.conf 							  #
# by EMR version 0.1 															  #
# à executer sur chaque node controller s'il n'est pas appelé par d'autres script #
###################################################################################
servicename=neutron
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

### recup time ###
timestamp() {
  date "+%Hh%M"
}

echo "Debut Opération sur $nodename à $(timestamp)" >> $script_log

### installing package on all controllers nodes ###
echo "Début installation des paquets pour le noeud $nodename" >> $script_log
   yum install openstack-neutron openstack-neutron-ml2 \
  openstack-neutron-linuxbridge ebtables -y
echo "Fin installation des paquets pour le noeaud $nodename" >> $script_log

## configuring neutron parameters on controller nodes ##
echo "Début configuration de neutron.conf sur $nodename" >> $script_log
openstack-config --set /etc/neutron/neutron.conf database connection mysql+pymysql://neutron:$admin_Pass@vip-mysql/neutron
openstack-config --set /etc/neutron/neutron.conf DEFAULT core_plugin  ml2
openstack-config --set /etc/neutron/neutron.conf DEFAULT service_plugins ""
openstack-config --set /etc/neutron/neutron.conf DEFAULT transport_url  rabbit://openstack:$admin_Pass@vip-rabbit
openstack-config --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone

openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_uri http://vip-keystone:5000
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_url http://vip-keystone:35357
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken memcached_servers $memcached_servers
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_type password
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken project_domain_name Default
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken user_domain_name Default
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken project_name service
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken username neutron
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken password $admin_Pass

openstack-config --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes True
openstack-config --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes True

openstack-config --set /etc/neutron/neutron.conf DEFAULT dhcp_agents_per_network 3

## conf nova sur neutron ##
openstack-config --set /etc/neutron/neutron.conf nova auth_url http://vip-keystone:35357
openstack-config --set /etc/neutron/neutron.conf nova auth_type password
openstack-config --set /etc/neutron/neutron.conf nova project_domain_name Default
openstack-config --set /etc/neutron/neutron.conf nova user_domain_name Default
openstack-config --set /etc/neutron/neutron.conf nova region_name RegionOne
openstack-config --set /etc/neutron/neutron.conf nova project_name service
openstack-config --set /etc/neutron/neutron.conf nova username nova
openstack-config --set /etc/neutron/neutron.conf nova auth_url password $admin_Pass
openstack-config --set /etc/neutron/neutron.conf oslo_concurrency lock_path /var/lib/neutron/tmp
echo "Fin configuration de neutron.conf sur $nodename" >> $script_log

## configuration du plugin ml2 neutron sur les controllers ##
echo "Début configuration de ml2_conf.ini sur $nodename" >> $script_log
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers flat,vlan
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types ""
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers linuxbridge
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 extension_drivers port_security
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks provider
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset True
echo "Fin configuration de ml2_conf.ini sur $nodename" >> $script_log

## configuration des agents linuxbridge neutron sur les controllers ##
echo "Début configuration de linuxbridge_agent.ini sur $nodename" >> $script_log
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini linux_bridge physical_interface_mappings provider:ens256
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan enable_vxlan False
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup enable_security_group True
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
echo "FIN configuration de linuxbridge_agent.ini sur $nodename" >> $script_log

## configuring dhcp-agent parameters on controller nodes ##
echo "Début configuration de dhcp_agent.ini sur $nodename" >> $script_log
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.BridgeInterfaceDriver
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT enable_isolated_metadata True
echo "Fin configuration de dhcp_agent.ini sur $nodename" >> $script_log

## configuration des metadata ##
echo "Début configuration de metadata_agent.ini sur $nodename" >> $script_log
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_ip vip-nova
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret $admin_Pass
echo "Fin configuration de metadata_agent.ini sur $nodename" >> $script_log

## creation lien symbolique pour le plugin ml2 ##
echo "creation lien symbolique pour le plugin ml2" >> $script_log
ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

## Fin conf ##
echo "Fin Opération  sur $nodename à $(timestamp)" >> $script_log

exit
