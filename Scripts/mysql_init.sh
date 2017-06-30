#!/bin/bash
###################################################################################
# script initialisation des bases de données des services OP					  #
# sur la base Mariadb	 							  							  #
# by EMR version 0.1 															  #
# à executer sur un seul node controller s'il n'est pas appelé par d'autres script#
###################################################################################
# Ce script requiert que la base est déjà prete #
mysql_admin_pass=dedjSD8dfDg
configdir_mysql=/srv/openstack/config/mysql
script_log=$configdir_mysql/mysql_init.log
service="keystone glance cinder nova neutron ceilometer horizon heat"

mkdir -p $configdir_mysql
galera_script=$configdir_mysql/galera.setup
echo "" > $galera_script
echo "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED by '$mysql_admin_pass' WITH GRANT OPTION;" >> $galera_script

for db in $services; do
    cat<<EOF >> $galera_script
CREATE DATABASE $db;
GRANT ALL ON $db.* TO '$db'@'%' IDENTIFIED BY '$mysql_admin_pass';
echo "Database $db créé" >> $script_log
EOF
done
echo "FLUSH PRIVILEGES;" >> $galera_script

#creation des bases de données #
mysql mysql < $galera_script
mysqladmin flush-hosts

echo "Fin" >> $script_log

exit



