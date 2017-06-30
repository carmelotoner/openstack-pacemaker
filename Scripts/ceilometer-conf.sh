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
 yum install openstack-ceilometer-api openstack-ceilometer-collector openstack-ceilometer-notification \
  openstack-ceilometer-central openstack-ceilometer-alarm python-ceilometer python-ceilometerclient redis python-redis -y
echo "Fin installation des paquets pour le noeud $nodename" >> $script_log

### configuring package on all controllers nodes ###
echo "Debut conf des paquets pour le noeud $nodename" >> $script_log
openstack-config --set /etc/ceilometer/ceilometer.conf database connection mongodb://ceilometer:$admin_Pass@$mongodb_servers/ceilometer
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
openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials password $admin_Pass
openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials interface internalURL
openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials region_name RegionOne

openstack-config --set /etc/ceilometer/ceilometer.conf coordination backend_url 'redis://vip-redis:6379'

openstack-config --set  /etc/ceilometer/ceilometer.conf database metering_time_to_live 432000
echo "Debut conf des paquets pour le noeud $nodename" >> $script_log

cat > /etc/httpd/conf.d/wsgi-ceilometer.conf << EOF
Listen 8777

<VirtualHost *:8777>
    WSGIDaemonProcess ceilometer-api processes=2 threads=10 user=ceilometer group=ceilometer display-name=%{GROUP}
    WSGIProcessGroup ceilometer-api
    WSGIScriptAlias / "/var/www/cgi-bin/ceilometer/app"
    WSGIApplicationGroup %{GLOBAL}
    ErrorLog /var/log/httpd/ceilometer_error.log
    CustomLog /var/log/httpd/ceilometer_access.log combined
</VirtualHost>

WSGISocketPrefix /var/run/httpd
EOF

echo "Début Opération  sur $nodename à $(timestamp)" >> $script_log
exit
