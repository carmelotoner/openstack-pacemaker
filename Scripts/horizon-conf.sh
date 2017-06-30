#!/bin/bash
###################################################################################
# script install neutron and configure cinder.conf 							      #
# by EMR version 0.1 															  #
# à executer sur un node controller s'il n'est pas appelé par d'autres script     #
###################################################################################
servicename=horizon
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
service="keystone glance cinder nova neutron ceilometer heat horizon"
memcached_servers="controller1:11211,controller2:11211,controller3:11211"

### installing package on all controllers nodes ###
echo "Début installation des paquets pour le noeud $nodename" >> $script_log
yum install openstack-dashboard -y
echo "Fin installation des paquets pour le noeaud $nodename" >> $script_log

### configuring local_settings on all controllers nodes ###

horizonememcachenodes=$(echo $memcached_servers | sed -e "s#,#', '#g" -e "s#^#[ '#g" -e "s#\$#', ]#g")

sed -i \
	-e "s#ALLOWED_HOSTS.*#ALLOWED_HOSTS = ['*',]#g" \
	-e "s#^CACHES#SESSION_ENGINE =   'django.contrib.sessions.backends.cache'\nCACHES#g#" \
	-e "s#locmem.LocMemCache'#memcached.MemcachedCache',\n\t'LOCATION' : $horizonememcachenodes#g" \
	-e 's#OPENSTACK_HOST =.*#OPENSTACK_HOST = "vip-keystone"#g' \
	-e "s#^LOCAL_PATH.*#LOCAL_PATH = '/var/lib/openstack-dashboard'#g" \
	-e "s#SECRET_KEY.*#SECRET_KEY = '$admin_Pass'#g#" \
	-e 's#OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT =.*#OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True#g' \
	-e 's#OPENSTACK_KEYSTONE_DEFAULT_DOMAIN =.*#OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = "default"#g' \
	-e 's#OPENSTACK_KEYSTONE_DEFAULT_ROLE =.*#OPENSTACK_KEYSTONE_DEFAULT_ROLE = "user"#g' \
	-e 's#OPENSTACK_HOST =.*#OPENSTACK_HOST = "vip-keystone"#g' \
	/etc/openstack-dashboard/local_settings
 


exit
