#!/bin/bash
sleep 5

service ssh restart

# Make backups of default sql config file
if [ ! -f /etc/freeradius/3.0/mods-available/sql.default ]; then
  cp /etc/freeradius/3.0/mods-available/sql /etc/freeradius/3.0/mods-available/sql.default
fi
# Make a backup of default daloradius.conf.php
if [ ! -f /var/www/daloradius/library/daloradius.conf.php.sample ]; then
  cp /var/www/daloradius/library/daloradius.conf.php /var/www/daloradius/library/daloradius.conf.php.sample
fi

if [ "$MYSQL_INIT_DATABASE" == "true" ]; then
  nohup mysqld >/dev/null 2>&1 &
  mkdir -p /var/www/daloradius/var/backup
  chown www-data:www-data /var/www/daloradius/var/backup
  # Secure MySQL/MariaDB
  SECURE_MYSQL=$(expect -c "
  set timeout 10
  spawn mysql_secure_installation
  expect \"Enter current password for root (enter for none):\"
  send \"\r\"
  expect \"Change the root password?\"
  send \"y\r\"
  expect \"New password:\"
  send \"$MYSQL_ROOT_PASS\r\"
  expect \"Re-enter new password:\"
  send \"$MYSQL_ROOT_PASS\r\"
  expect \"Remove anonymous users?\"
  send \"y\r\"
  expect \"Disallow root login remotely?\"
  send \"y\r\"
  expect \"Remove test database and access to it?\"
  send \"y\r\"
  expect \"Reload privilege tables now?\"
  send \"y\r\"
  expect eof
  ")
  echo "$SECURE_MYSQL"

  echo "Initializing MySQL Database."
  # MYSQL="mysql -u$MYSQL_USER -p$MYSQL_PASS -h $MYSQL_HOST --port $MYSQL_PORT" 
  MYSQL="mysql -uroot -p'$MYSQL_ROOT_PASS' -h $MYSQL_HOST --port $MYSQL_PORT" 
  # $MYSQL -e "CREATE DATABASE $MYSQL_DATABASE; GRANT ALL ON $MYSQL_USER.* TO $MYSQL_DATABASE@% IDENTIFIED BY '$MYSQL_PASS'; \
  $MYSQL -e "CREATE DATABASE $MYSQL_DATABASE; \
  CREATE USER '$MYSQL_USER'@'localhost' IDENTIFIED by '$MYSQL_PASS'; 
  GRANT ALL PRIVILEGES ON $MYSQL_DATABASE.* TO '$MYSQL_USER'@'localhost'; \
  flush privileges;"

  $MYSQL $MYSQL_DATABASE  < /etc/freeradius/3.0/mods-config/sql/main/mysql/schema.sql
  # $MYSQL $MYSQL_DATABASE  < /etc/freeradius/sql/mysql/nas.sql
  $MYSQL $MYSQL_DATABASE  < /var/www/daloradius/contrib/db/fr2-mysql-daloradius-and-freeradius.sql
  $MYSQL $MYSQL_DATABASE  < /var/www/daloradius/contrib/db/mysql-daloradius.sql
fi

sed -i -e 's|authorize {|authorize {\nsql|' /etc/freeradius/3.0/sites-available/inner-tunnel
sed -i -e 's|session {|session {\nsql|' /etc/freeradius/3.0/sites-available/inner-tunnel 
sed -i -e 's|authorize {|authorize {\nsql|' /etc/freeradius/3.0/sites-available/default
sed -i -e 's|session {|session {\nsql|' /etc/freeradius/3.0/sites-available/default
sed -i -e 's|accounting {|accounting {\nsql|' /etc/freeradius/3.0/sites-available/default
sed -i -e 's|\t#  See "Authentication Logging Queries" in sql.conf\n\t#sql|#See "Authentication Logging Queries" in sql.conf\n\tsql|g' /etc/freeradius/3.0/sites-available/inner-tunnel 
sed -i -e 's|\t#  See "Authentication Logging Queries" in sql.conf\n\t#sql|#See "Authentication Logging Queries" in sql.conf\n\tsql|g' /etc/freeradius/3.0/sites-available/default

sed -i -e 's/$INCLUDE sql.conf/\n$INCLUDE sql.conf/g' /etc/freeradius/3.0/radiusd.conf
sed -i -e 's|$INCLUDE sql/mysql/counter.conf|\n$INCLUDE sql/mysql/counter.conf|g' /etc/freeradius/3.0/radiusd.conf
sed -i -e 's|auth_badpass = no|auth_badpass = yes|g' /etc/freeradius/3.0/radiusd.conf
sed -i -e 's|auth_goodpass = no|auth_goodpass = yes|g' /etc/freeradius/3.0/radiusd.conf
sed -i -e 's|auth = no|auth = yes|g' /etc/freeradius/3.0/radiusd.conf
# sed -i -e 's|sqltrace = no|sqltrace = yes|g' /etc/freeradius/3.0/sql.conf
# sed -i -e "s/readclients = yes/nreadclients = yes/" /etc/freeradius/3.0/sql.conf

echo -e "\nATTRIBUTE Usage-Limit 3000 string\nATTRIBUTE Rate-Limit 3001 string" >> /etc/freeradius/3.0/dictionary


sed -i -e 's|cleanup_delay = 5|cleanup_delay = 10|g' /etc/freeradius/3.0/radiusd.conf
sed -i -e 's|max_requests = 16384|max_requests = 500000|g' /etc/freeradius/3.0/radiusd.conf
sed -i -e 's|reject_delay = 1|reject_delay = 1|g' /etc/freeradius/3.0/radiusd.conf
sed -i -e 's|start_servers = 5|start_servers = 100|g' /etc/freeradius/3.0/radiusd.conf
sed -i -e 's|max_servers = 32|max_servers = 2500|g' /etc/freeradius/3.0/radiusd.conf
sed -i -e 's|min_spare_servers = 3|min_spare_servers = 25|g' /etc/freeradius/3.0/radiusd.conf
sed -i -e 's|max_spare_servers = 10|max_spare_servers = 100|g' /etc/freeradius/3.0/radiusd.conf


# Unset CLIENT_NET in case it's set (without numbers at end). 
unset CLIENT_NET

# Parse the multiple CLIENT_NETx variables and append them to the configuration
env | grep 'CLIENT_NET' | sort | while read extraline; do
echo "# $extraline " >> /etc/freeradius/3.0/clients.conf
linekey=$(echo $extraline | cut -d'=' -f1)
linevalue=$(echo $extraline | cut -d'=' -f2-)
echo "client $linekey { 
  ipaddr = $linevalue
  secret = $CLIENT_SECRET
  limit {
    max_connections = $CLIENT_MAX_CONNECTIONS
    idle_timeout = $CLIENT_IDLE_TIMEOUT
  }
}" >> /etc/freeradius/3.0/clients.conf
done

# to use nas table in radius db for clients
sed -i -e 's|ipaddr = 127.0.0.1|ipaddr = 127.0.0.2|g' /etc/freeradius/3.0/clients.conf

# if [ -n "$CLIENT_NET" ]; then
# echo "client $CLIENT_NET { 
#     	secret          = $CLIENT_SECRET 
#     	shortname       = clients 
# }" >> /etc/freeradius/3.0/clients.conf
# fi 


mkdir /run/php

echo "init.sh: completed"