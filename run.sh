#!/bin/bash
echo "start init"

# Run init.sh once then remove the line from run.sh
/init.sh
sed -i "s/^\/init.sh//" /run.sh

# Update DB Values for FreeRadius
# https://bytexd.com/freeradius-ubuntu/
cp /etc/freeradius/3.0/mods-available/sql.default /etc/freeradius/3.0/mods-available/sql
sed -i -e 's/driver = "rlm_sql_null"/driver = "rlm_sql_${dialect}"/g' /etc/freeradius/3.0/mods-available/sql
sed -i -e 's/dialect = "sqlite"/dialect = "mysql"/g' /etc/freeradius/3.0/mods-available/sql
sed -i -e 's/ca_file = "/#ca_file = "/g' /etc/freeradius/3.0/mods-available/sql
sed -i -e 's/ca_path = "/#ca_path = "/g' /etc/freeradius/3.0/mods-available/sql
sed -i -e 's/certificate_file = "/#certificate_file = "/g' /etc/freeradius/3.0/mods-available/sql
sed -i -e 's/private_key_file = "/#private_key_file = "/g' /etc/freeradius/3.0/mods-available/sql
sed -i -e 's/cipher = "/#cipher = "/g' /etc/freeradius/3.0/mods-available/sql
sed -i -e 's/tls_required = /#tls_required = /g' /etc/freeradius/3.0/mods-available/sql
sed -i -e 's/tls_check_cert = /#tls_check_cert = /g' /etc/freeradius/3.0/mods-available/sql
sed -i -e 's/tls_check_cert_cn = /#tls_check_cert_cn = /g' /etc/freeradius/3.0/mods-available/sql
sed -i -e 's/#\s*read_clients = yes/\tread_clients = yes/g' /etc/freeradius/3.0/mods-available/sql
sed -i -e 's/#\s*server = "localhost"/\tserver = "'$MYSQL_HOST'"/g' /etc/freeradius/3.0/mods-available/sql
sed -i -e 's/#\s*port = 3306/\tport = '$MYSQL_PORT'/g' /etc/freeradius/3.0/mods-available/sql
sed -i -e 's/#\s*login = "radius"/\tlogin = "'$MYSQL_USER'"/g' /etc/freeradius/3.0/mods-available/sql
sed -i -e 's/#\s*password = "radpass"/\tpassword = "'$MYSQL_PASS'"/g' /etc/freeradius/3.0/mods-available/sql
sed -i -e 's/radius_db = "radius"/radius_db = "'$MYSQL_DATABASE'"/g' /etc/freeradius/3.0/mods-available/sql

# Update DB Values or daloRADIUS
cp /var/www/daloradius/library/daloradius.conf.php.sample /var/www/daloradius/library/daloradius.conf.php
sed -i -e "s/\$configValues\['CONFIG_DB_HOST'\] = 'localhost';/\$configValues\['CONFIG_DB_HOST'\] = '"$MYSQL_HOST"';/" /var/www/daloradius/library/daloradius.conf.php
sed -i -e "s/\$configValues\['CONFIG_DB_PORT'\] = '3306';/\$configValues\['CONFIG_DB_PORT'\] = '"$MYSQL_PORT"';/" /var/www/daloradius/library/daloradius.conf.php
sed -i -e "s/\$configValues\['CONFIG_DB_USER'\] = 'root';/\$configValues\['CONFIG_DB_USER'\] = '"$MYSQL_USER"';/" /var/www/daloradius/library/daloradius.conf.php
sed -i -e "s/\$configValues\['CONFIG_DB_PASS'\] = '';/\$configValues\['CONFIG_DB_PASS'\] = '"$MYSQL_PASS"';/" /var/www/daloradius/library/daloradius.conf.php
sed -i -e "s/\$configValues\['CONFIG_DB_NAME'\] = 'radius';/\$configValues\['CONFIG_DB_NAME'\] = '"$MYSQL_DATABASE"';/" /var/www/daloradius/library/daloradius.conf.php

mkdir -p /run/php & 
php-fpm7.2 & 
nginx & 
screen -wipe; screen -dmS radius /bin/bash -i; screen -S radius -X stuff "/usr/sbin/freeradius -X^M"
