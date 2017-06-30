#!/bin/bash
###################################################################################
# Debut configuration des services pour remotekey							      #
# by EMR version 0.1 															  #
# à executer sur un controller après la configuration de tous les services
# keystone glance neutron cinder  		  
###################################################################################
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
all_nodelist=$controller_nodelist" "$compute_nodelist
script_log=$configdir/$servicename/$servicename-install.log  
service="keystone glance cinder nova neutron ceilometer horizon heat"
memcached_servers="controller1:11211,controller2:11211,controller3:11211"


iptables -A INPUT -p tcp -m state --state NEW -m tcp --dport  3121 -j ACCEPT
iptables -A INPUT -p tcp -m state --state NEW -m tcp --dport  3121 -j ACCEPT

timestamp() {
  date "+%Hh%M"
}

echo "Debut Opération  sur $node à $(timestamp)" >> $script_log

# add NovaEvacuate. It must be A/P and that is perfectly acceptable
# to avoid need of a cluster wide locking
#pcs resource create nova-evacuate ocf:openstack:NovaEvacuate auth_url=http://vip-keystone:35357/v3/ username=admin password=$admin_Pass project_name=admin

# without any of those services, nova-evacuate is useless
# later we also add a order start on nova-compute (after -compute is defined)
#for i in vip-glance vip-cinder vip-neutron vip-nova vip-db vip-rabbitmq vip-keystone cinder-volume; do
# pcs constraint order start $i then nova-evacuate
#done

#for i in glance-api-clone neutron-metadata-agent-clone nova-conductor-clone; do
#  pcs constraint order start $i then nova-evacuate require-all=false
#done

# Take down the ODP control plane
pcs resource disable openstack-keystone --wait=240

# Take advantage of the fact that control nodes will already be part of the cluster
# At this step, we need to teach the cluster about the compute nodes
#
# This requires running commands on the cluster based on the names of the compute nodes
### recup time ###


controllers=$(cibadmin -Q -o nodes | grep uname | sed s/.*uname..// | awk -F\" '{print $1}')

for controller in ${controllers}; do
    pcs property set --node $controller osprole=controller
done

# Force services to run only on nodes with osprole = controller
#
# Importantly it also tells Pacemaker not to even look for the services on other
# nodes. This helps reduce noise and collisions with services that fill the same role
# on compute nodes.

#stonithdevs=$(pcs stonith | awk '{print $1}')

for i in $(cibadmin -Q --xpath //primitive --node-path | tr ' ' '\n' | awk -F "id='" '{print $2}' | awk -F "'" '{print $1}' | uniq); 
do 
   pcs constraint location $i rule resource-discovery=exclusive score=0 osprole eq controller
done

# Now (because the compute nodes have roles assigned to them and keystone is
# stopped) it is safe to define the services that will run on the compute nodes

# neutron-linuxbridge-agent
echo "creation et affectation des services sur les noeuds compute " >> $script_log
echo "creation de la resource neutron-linuxbridge-agent-compute pour les noeuds compute " >> $script_log
pcs resource create neutron-linuxbridge-agent-compute systemd:neutron-linuxbridge-agent --clone interleave=true --disabled --force
echo "creation de la contrainte neutron-linuxbridge-agent-compute pour les noeuds compute " >> $script_log
pcs constraint location neutron-linuxbridge-agent-compute-clone rule resource-discovery=exclusive score=0 osprole eq compute 
pcs constraint order start neutron-server-clone then neutron-linuxbridge-agent-compute-clone require-all=false


# neutron-dhcp-agent
echo "creation de la resource neutron-dhcp-agent-compute pour les noeuds compute " >> $script_log
pcs resource create neutron-dhcp-agent-compute systemd:neutron-dhcp-agent --clone interleave=true
pcs constraint location neutron-dhcp-agent-compute-clone rule resource-discovery=exclusive score=0 osprole eq compute 
pcs constraint order start neutron-linuxbridge-agent-compute-clone then neutron-dhcp-agent-compute-clone
pcs constraint colocation add neutron-dhcp-agent-compute-clone with neutron-linuxbridge-agent-compute-clone

# libvirtd
echo "creation de la resource libvirtd-compute pour les noeuds compute" >> $script_log
pcs resource create libvirtd-compute systemd:libvirtd --clone interleave=true --disabled --force
echo "creation de la contrainte neutron-linuxbridge-agent-compute pour les noeuds compute" >> $script_log
pcs constraint location libvirtd-compute-clone rule resource-discovery=exclusive score=0 osprole eq compute
pcs constraint order start neutron-linuxbridge-agent-compute-clone then libvirtd-compute-clone
pcs constraint colocation add libvirtd-compute-clone with neutron-linuxbridge-agent-compute-clone

# openstack-ceilometer-compute
echo "creation de la resource ceilometer-compute pour les noeuds compute" >> $script_log
pcs resource create openstack-ceilometer-compute systemd:openstack-ceilometer-compute --clone interleave=true --disabled --force
echo "creation des contraintes ceilometer-compute pour les noeuds compute" >> $script_log
pcs constraint location openstack-ceilometer-compute-clone rule resource-discovery=exclusive score=0 osprole eq compute
pcs constraint order start openstack-ceilometer-notification-clone then openstack-ceilometer-compute-clone require-all=false
pcs constraint order start libvirtd-compute-clone then openstack-ceilometer-compute-clone
pcs constraint colocation add openstack-ceilometer-compute-clone with libvirtd-compute-clone

# nfs mount for nova-compute shared storage
echo "creation de la resource openstack-nova-compute-fs pour les noeuds compute" >> $script_log
pcs resource create openstack-nova-compute-fs Filesystem  device="$nfs_server:$configdir/instances" directory="/var/lib/nova/instances" fstype="nfs" options="v3" op start timeout=240 --clone interleave=true --disabled --force
#pcs resource create openstack-nova-compute-fs Filesystem  device="10.102.0.56:/instances" directory="/var/lib/nova/instances" fstype="nfs" options="v3" op start timeout=240 --clone interleave=true --disabled --force
echo "creation des contraintes openstack-nova-compute-fs pour les noeuds compute" >> $script_log
pcs constraint location openstack-nova-compute-fs-clone rule resource-discovery=exclusive score=0 osprole eq compute
pcs constraint order start openstack-ceilometer-compute-clone then openstack-nova-compute-fs-clone
pcs constraint colocation add openstack-nova-compute-fs-clone with openstack-ceilometer-compute-clone

# nova-compute
echo "creation de la resource openstack-nova-compute pour les noeuds compute" >> $script_log
pcs resource create openstack-nova-compute ocf:openstack:NovaCompute auth_url=http://vip-keystone:35357/v3 username=admin password=$admin_Pass project_name=admin domain=${PHD_VAR_network_domain} op start timeout=300 --clone interleave=true --disabled --force
#pcs resource create openstack-nova-compute ocf:openstack:NovaCompute auth_url=http://vip-keystone:35357/v3/ username=admin password=voiture tenant_name=admin domain=ftoma.mg op start timeout=300 --clone interleave=true --disabled --force
pcs constraint location openstack-nova-compute-clone rule resource-discovery=exclusive score=0 osprole eq compute
pcs constraint order start openstack-nova-conductor-clone then openstack-nova-compute-clone require-all=false
pcs constraint order start openstack-nova-compute-fs-clone then openstack-nova-compute-clone require-all=false
pcs constraint colocation add openstack-nova-compute-clone with openstack-nova-compute-fs-clone



#pcs constraint order start openstack-nova-compute-clone then nova-evacuate require-all=false

#case ${PHD_VAR_network_hosts_gateway} in
#    east-*)
#	pcs stonith create fence-compute fence_apc ipaddr=east-apc login=apc passwd=apc pcmk_host_map="east-01:2;east-02:3;east-03:4;east-04:5;east-05:6;east-06:7;east-07:9;east-08:10;east-09:11;east-10:12;east-11:13;east-12:14;east-13:15;east-14:18;east-15:17;east-16:19;" --force
#    ;;
#    mrg-*)
#	pcs stonith create fence-compute fence_apc_snmp ipaddr=apc-ap7941-l2h3.mgmt.lab.eng.bos.redhat.com power_wait=10 pcmk_host_map="mrg-07:10;mrg-08:12;mrg-09:14"
#    ;;
#esac

#pcs stonith create fence-nova fence_compute auth-url=http://vip-keystone:35357/v3 login=admin passwd=$admin_Pass project_name=admin domain=${PHD_VAR_network_domain} record-only=1 action=off --force

# while this is set in basic.cluster, it looks like OSPd doesn't set it.
pcs resource defaults resource-stickiness=INFINITY

# allow compute nodes to rejoin the cluster automatically
# 1m might be a bit aggressive tho
pcs property set cluster-recheck-interval=1min

for node in $compute_nodelist; 
do
    #found=0
    #short_node=$(echo ${node} | sed s/\\..*//g)

    #for controller in ${controllers}; do
	#if [ ${short_node} = ${controller} ]; then
	#    found=1
	#fi
    #done

    #if [ $found = 0 ]; then
	# We only want to execute the following _for_ the compute nodes, not _on_ the compute nodes
	# Rather annoying
    
	pcs resource create $node ocf:pacemaker:remote reconnect_interval=60 op monitor interval=20
	pcs property set --node $node osprole=compute
	#pcs stonith level add 1 $node fence-compute,fence-nova
    #fi
done

pcs resource enable openstack-keystone
pcs resource enable neutron-linuxbridge-agent-compute
pcs resource enable libvirtd-compute
pcs resource enable openstack-ceilometer-compute
pcs resource enable openstack-nova-compute-fs
pcs resource enable openstack-nova-compute

# cleanup after us
sleep 60
pcs resource cleanup

## Fin conf ##
echo "Fin Opération  sur $node à $(timestamp)" >> $script_log

exit
