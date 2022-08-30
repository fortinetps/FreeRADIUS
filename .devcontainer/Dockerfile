FROM ubuntu:bionic

ENV MYSQL_INIT_DATABASE "true"
ENV MYSQL_HOST "localhost"
ENV MYSQL_PORT "3306"
ENV MYSQL_ROOT_PASS "R&sY1olOns9KstOdv*uj"
ENV MYSQL_DATABASE "radius"
ENV MYSQL_USER "radius"
ENV MYSQL_PASS "R7EwFA!96u0Vg90Cmnos"
# ENV CLIENT_NET1 "0.0.0.0/0"
# ENV CLIENT_SECRET "testing123"
ENV CLIENT_MAX_CONNECTIONS "16"
ENV CLIENT_IDLE_TIMEOUT "30"

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get -y upgrade
RUN apt-get install -y nginx php php-fpm php-common php-gd php-curl php-mail php-mail-mime php-pear php-db php-mysqlnd && pear install DB
RUN apt-get install -y mariadb-server
RUN apt-get install -y freeradius freeradius-mysql freeradius-utils
RUN apt-get install -y wget unzip expect net-tools screen vim openssh-server
RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /root/.cpan	

RUN wget https://github.com/lirantal/daloradius/archive/master.zip && \
	unzip *.zip && \
	mv daloradius-master /var/www/daloradius && \
 	chown -R www-data:www-data /var/www/daloradius && \
  cp /var/www/daloradius/library/daloradius.conf.php.sample /var/www/daloradius/library/daloradius.conf.php && \
	chmod 644 /var/www/daloradius/library/daloradius.conf.php && \
	rm /etc/nginx/sites-enabled/default

COPY init.sh /
COPY run.sh /
RUN chmod +x /init.sh && chmod +x /run.sh
COPY etc/nginx/radius.conf /etc/nginx/sites-enabled/

# Enable Additional FreeRadius Mods
RUN ln -s /etc/freeradius/3.0/mods-available/sql /etc/freeradius/3.0/mods-enabled/sql

RUN mkdir -p /var/lib/mysql /var/run/mysqld && \
  chown -R mysql:mysql /var/lib/mysql /var/run/mysqld && \
  mkdir /var/run/sshd && \
  echo root:PASSWORD_FOR_USER_root | chpasswd && \
  sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
  sed -i 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' /etc/pam.d/sshd

EXPOSE 3306 1812 1813 80 22

ENTRYPOINT ["/run.sh"]