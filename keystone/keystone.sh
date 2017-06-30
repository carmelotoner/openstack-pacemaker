#!/bin/bash
###################################################################################
# script installation et initialisation du service Keystone et 					  #
# configure keystone.conf 							  							  #
# by EMR version 0.1 															  #
# à executer sur un seul node controller s'il n'est pas appelé par d'autres script#
###################################################################################
servicename=keystone
hostname=`hostname |sed 's/.ftoma.mg*//'`
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
services="keystone glance cinder nova neutron ceilometer horizon heat"

## installation et configuration des paquets en appelant le script keystone_conf.sh ##
for node in $controller_nodelist;
do 
   echo "Debut installation sur $node" >> $script_log
   ssh $node bash -c "'$configdir/keystone/keystone_conf.sh'" 
done

## initialize the DB ##
su -s /bin/sh -c "keystone-manage db_sync" keystone
echo "initialisation de la base keystone effectuée " >> $script_log

keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
echo "initialisation des clé Fernet keystone effectuée " >> $script_log

## boostrap du service keystone le node 1 ##
keystone-manage bootstrap --bootstrap-password $admin_Pass \
  --bootstrap-admin-url http://vip-keystone:35357/v3/ \
  --bootstrap-internal-url http://vip-keystone:35357/v3/ \
  --bootstrap-public-url http://vip-keystone:5000/v3/ \
  --bootstrap-region-id RegionOne
echo "boostrap du service keystone effectuée " >> $script_log  
  
## copie des key_repository fernet depuis le node 1 ###

for node in $controller_nodelist;
do
    scp -r /etc/keystone/credential-keys/* root@$node:/etc/keystone/credential-keys/
done
echo "Copie des keys fernet du service keystone effectuée " >> $script_log 

## creating pacemaker keystone resource ##
pcs resource create openstack-keystone systemd:httpd --clone interleave=true
pcs constraint order start rabbitmq-clone then openstack-keystone-clone
pcs constraint order start memcached-clone then openstack-keystone-clone
echo "Configuration de la resource openstack-keystone effectuée dans le cluster" >> $script_log 


## setting user auth credential ##
export OS_USERNAME=admin
export OS_PASSWORD=$admin_Pass
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://vip-keystone:35357/v3
export OS_IDENTITY_API_VERSION=3

## creating "Service Project" projects ###
openstack project create --domain default --description "Service Project" service
echo "Creation du projet 'service' effectuée " >> $script_log 

## creating "Demo Project" projects ###
openstack project create --domain default \
  --description "Demo Project" demo
  
## creating "Demo user ##
openstack user create --domain default \
  --password $demo_Pass demo
  
## creating "user role" ##  
openstack role create user

## add user demo to user role ###
openstack role add --project demo --user demo user
echo "Creation de l'utilisateur 'demo' effectuée " >> $script_log 

## creating admin rc file ##
cat >  $configdir/keystonerc_admin << EOF
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$admin_Pass
export OS_AUTH_URL=http://vip-keystone:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
export PS1='[\u@\h \W(keystone_admin)]\$ '
EOF

## creating demo rc file ##
cat >  $configdir/keystonerc_user << EOF
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=demo
export OS_USERNAME=demo
export OS_PASSWORD=demo
export OS_AUTH_URL=http://vip-keystone:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
export PS1='[\u@\h \W(keystone_user)]\$ '
EOF

echo "Creation des .rc files effectuée " >> $script_log 

## initialisation des autres services ##
cd $configdir
. keystonerc_admin

## For Glance ##
echo "configuring glance api endpoints" >> $script_log
openstack user create --domain default --password $admin_Pass glance
openstack role add --project service --user glance admin
openstack service create --name glance --description "OpenStack Image" image
openstack endpoint create --region RegionOne image public http://vip-glance:9292
openstack endpoint create --region RegionOne image internal http://vip-glance:9292
openstack endpoint create --region RegionOne image admin http://vip-glance:9292
echo "configuring glance api endpoints done" >> $script_log
## Fin Glance ##

## For Nova ##
echo "configuring nova endpoints" >> $script_log
openstack user create --domain default --password $admin_Pass nova
openstack role add --project service --user nova admin
openstack service create --name nova --description "OpenStack Compute" compute
openstack endpoint create --region RegionOne compute public http://vip-nova:8774/v2.1/%\(tenant_id\)s
openstack endpoint create --region RegionOne compute internal http://vip-nova:8774/v2.1/%\(tenant_id\)s
openstack endpoint create --region RegionOne compute admin http://vip-nova:8774/v2.1/%\(tenant_id\)s
echo "configuring nova api endpoints done" >> $script_log
## Fin Nova ##

## Debut Neutron ##
echo "configuring neutron endpoints" >> $script_log
openstack user create --domain default --password $admin_Pass neutron
openstack role add --project service --user neutron admin
openstack service create --name neutron --description "OpenStack Networking" network
openstack endpoint create --region RegionOne network public http://vip-neutron:9696
openstack endpoint create --region RegionOne network internal http://vip-neutron:9696
openstack endpoint create --region RegionOne network admin http://vip-neutron:9696
echo "configuring neutron endpoints done" >> $script_log
## Fin Neutron ##

## Début Cinder ##
echo "configuring cinder endpoints" >> $script_log
openstack user create --domain default --password $admin_Pass cinder
openstack role add --project service --user cinder admin
openstack service create --name cinder --description "OpenStack Block Storage" volume
openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2
openstack endpoint create --region RegionOne volume public http://vip-cinder:8776/v1/%\(tenant_id\)s
openstack endpoint create --region RegionOne volume internal http://vip-cinder:8776/v1/%\(tenant_id\)s
openstack endpoint create --region RegionOne volume admin http://vip-cinder:8776/v1/%\(tenant_id\)s
openstack endpoint create --region RegionOne volumev2 public http://vip-cinder:8776/v2/%\(tenant_id\)s
openstack endpoint create --region RegionOne volumev2 internal http://vip-cinder:8776/v2/%\(tenant_id\)s
openstack endpoint create --region RegionOne volumev2 admin http://vip-cinder:8776/v2/%\(tenant_id\)s
echo "configuring cinder endpoints done" >> $script_log
## Fin Cinder ##

## Debut Ceilometer ##
openstack user create --domain default --password $admin_Pass ceilometer
openstack role add --project service --user ceilometer admin
openstack service create --name ceilometer --description "Telemetry" metering
openstack endpoint create --region RegionOne metering public http://vip-ceilometer:8777
openstack endpoint create --region RegionOne metering internal http://vip-ceilometer:8777
openstack endpoint create --region RegionOne metering admin http://vip-ceilometer:8777
## Fin Ceilometer ##

##debut Heat ##
openstack user create --domain default --password $admin_Pass heat
openstack role add --project service --user heat admin
openstack service create --name heat --description "Orchestration" orchestration
openstack service create --name heat-cfn --description "Orchestration"  cloudformation
openstack endpoint create --region RegionOne orchestration public http://vip-heat:8004/v1/%\(tenant_id\)s
openstack endpoint create --region RegionOne orchestration internal http://vip-heat:8004/v1/%\(tenant_id\)s
openstack endpoint create --region RegionOne orchestration admin http://vip-heat:8004/v1/%\(tenant_id\)s
openstack endpoint create --region RegionOne cloudformation public http://vip-heat:8000/v1
openstack endpoint create --region RegionOne cloudformation internal http://vip-heat:8000/v1
openstack endpoint create --region RegionOne cloudformation admin http://vip-heat:8000/v1
openstack domain create --description "Stack projects and users" heat
openstack user create --domain heat --password $admin_Pass heat_domain_admin
openstack role add --domain heat --user-domain heat --user heat_domain_admin admin
openstack role create heat_stack_owner
openstack role add --project demo --user demo heat_stack_owner
openstack role create heat_stack_user
## Fin Heat ##



exit 
