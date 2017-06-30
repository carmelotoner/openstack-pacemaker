#!/bin/bash
###################################################################################
# script install Keystone and configure keystone.conf 							  #
# by EMR version 0.1 															  #
# à executer sur chaque node controller s'il n'est pas appelé par d'autres script #
###################################################################################

nodename=`hostname |sed 's/.ftoma.mg*//'`
network_Admin=10.101.0
network_Stor=10.102.0
ip_Admin=`ifconfig | grep "$network_Admin" |awk -F " " '{print $2}'`
admin_Pass=dksdhDnci12h
demo_Pass=demo
configdir=/srv/openstack/config ## /srv/openstack est un point de montage nfs monté sur tous les noeuds ##
controller_nodelist="controller1 controller2 controller3"
compute_nodelist="compute1 compute2"
script_log=$configdir/keystone_install.log  
#service="keystone glance cinder nova neutron ceilometer horizon"

### installing package on all controller nodes ###
yum install -y openstack-keystone openstack-utils python-openstackclient httpd mod_wsgi
echo "paquets openstack-keystone openstack-utils python-openstackclient httpd mod_wsgi installés sur $nodename" >> $script_log

## configuring keystone parameters on  controller nodes ##
openstack-config --set /etc/keystone/keystone.conf database connection mysql+pymysql://keystone:$admin_Pass@vip-mysql/keystone
openstack-config --set /etc/keystone/keystone.conf database max_retries -1

openstack-config --set /etc/keystone/keystone.conf DEFAULT bind_host  $ip_Admin
openstack-config --set /etc/keystone/keystone.conf DEFAULT public_bind_host  $ip_Admin
openstack-config --set /etc/keystone/keystone.conf DEFAULT admin_bind_host  $ip_Admin

openstack-config --set /etc/keystone/keystone.conf catalog driver keystone.catalog.backends.sql.Catalog

openstack-config --set /etc/keystone/keystone.conf identity driver keystone.identity.backends.sql.Identity

openstack-config --set /etc/keystone/keystone.conf credential provider fernet 
openstack-config --set /etc/keystone/keystone.conf credential key_repository /etc/keystone/credential-keys/

## configuration httpd ##
sed -i "s|"ServerName.*"|"ServerName\ \$hostname"|" /etc/httpd/conf/httpd.conf
ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/
echo "Configuration du service httpd effectuée " >> $script_log 

echo "Configuration openstack-keystone sur $nodename terminée" >> $script_log
exit 