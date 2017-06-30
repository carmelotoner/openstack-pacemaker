#!/bin/bash
###################################################################################
# script initialisation de l'environnement de travail à executer avant tout 	  #
# les scripts Openstack							  							  	  #
# by EMR version 0.1 															  #
# à executer sur un seul node controller s'il n'est pas appelé par d'autre script #
###################################################################################
servicename=env
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
nfs_list="nfs"
all_nodelist=$nfs_list" "$controller_nodelist" "$compute_nodelist
domaine:ftoma.mg
script_log=$configdir/$servicename.log  
services="keystone glance cinder neutron nova ceilometer heat horizon"
infras="rabbit mysql redis"
dns_temp=/etc/dns_temp
proxy_temp=/etc/proxy_temp
echo "localhost,127.0.0.1,*.ftoma.mg," > $proxy_temp
tcp_ports="5000,35357,9292,9696,8000,8004,8774,8776,8777,443,80,2224,3306,5666,13724,1556,1383,13722,2821,1556,13783,1324,13782,6106,1500,3121"
udp_ports="161"
iptables_rules=/etc/sysconfig/iptables_rules.txt
echo "Debut config $servicename" >> $script_log

echo "config firewall pour tous les noeuds" >> $script_log
## Conf firewall ##
yum install iptables-services -y
## edit firewall rules ##
touch $iptables_rules
for port in $tcp_ports; do
   echo "iptables -A INPUT  -p tcp --dport $port -j ACCEPT" >> $iptables_rules
done
for port in $udp_ports; do
   echo "iptables -A INPUT  -p udp --dport $port -j ACCEPT" >> $iptables_rules
done
## apply to /etc/sysconfig/iptables ##
cp /etc/sysconfig/iptables /etc/sysconfig/iptables.old
sed -i '/:OUTPUT ACCEPT \[0:0\]/r $iptables_rules' /etc/sysconfig/iptables
## disable firewalld ##
systemctl stop firewalld && systemctl disable firewalld && systemctl enable iptables && systemctl start iptables; systemctl start ip6tables
echo "Fin config firewall pour tous les noeuds" >> $script_log

## Disable selinux ##
echo  "config Selinux pour tous les noeuds" >> $script_log
	cp /etc/sysconfig/selinux /etc/sysconfig/selinux.bak
	setenforce 0
	sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/sysconfig/selinux 
echo  "Fin config Selinux pour tous les noeuds" >> $script_log



#all=$all_nodelist" "$infras" "$services
## setup /etc/hosts ##
declare -i IP=10
pattern=ftoma.mg
echo "Configuration de la resolution de nom" >> $script_log
for srv in $all_nodelist;
do 
   sed -i "/${pattern},/ s/$/${srv},/" $proxy_temp
   ssh root@$srv bash -c "'echo $network_Admin.$IP $srv.ftoma.mg $srv >> /etc/hosts'"
   IP=$IP+1
   pattern=$srv
done
for srv in "$infras" "$services";
do 
   sed -i "/${pattern},/ s/$/${srv},/" $proxy_temp
   ssh root@$srv bash -c "'echo $network_Admin.$IP  vip-$srv >> /etc/hosts'"
   IP=$IP+1
   pattern=$srv
done
echo "Fin Configuration de la resolution de nom" >> $script_log

## setup proxy_env ##
for srv in $all_nodelist" "$infras;
do
   echo $pattern
   sed -i "/${pattern},/ s/$/${srv},/" $proxy_temp
   pattern=$srv
done

# sed '/ftoma.mg,/ s/$/controller1,/' /etc/proxy_temp
## creation des repertoires de configurations ###
for service in $services;
do
  mkdir -p $configdir/$service
  echo "Repertoire $configdir/$service créé" >> $script_log
done


exit

