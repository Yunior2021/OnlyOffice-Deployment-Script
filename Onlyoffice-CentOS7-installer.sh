#!/bin/bash
#
echo '[nginx-stable]' >> /etc/yum.repos.d/nginx.repo
echo 'name=nginx stable repo' >> /etc/yum.repos.d/nginx.repo
echo 'baseurl=http://nginx.org/packages/centos/$releasever/$basearch/' >> /etc/yum.repos.d/nginx.repo
echo 'gpgcheck=1' >> /etc/yum.repos.d/nginx.repo
echo 'enabled=1' >> /etc/yum.repos.d/nginx.repo
echo 'gpgkey=https://nginx.org/keys/nginx_signing.key' >> /etc/yum.repos.d/nginx.repo
echo '' >> /etc/yum.repos.d/nginx.repo
#
echo '[nginx-mainline]' >> /etc/yum.repos.d/nginx.repo
echo 'name=nginx mainline repo' >> /etc/yum.repos.d/nginx.repo
echo 'baseurl=http://nginx.org/packages/mainline/centos/$releasever/$basearch/' >> /etc/yum.repos.d/nginx.repo
echo 'gpgcheck=1' >> /etc/yum.repos.d/nginx.repo
echo 'enabled=0' >> /etc/yum.repos.d/nginx.repo
echo 'gpgkey=https://nginx.org/keys/nginx_signing.key' >> /etc/yum.repos.d/nginx.repo
#
sudo yum remove nodejs npm -y
#
sudo curl -sL https://rpm.nodesource.com/setup_12.x | bash -
#
sudo yum install nodejs gcc-c++ make yarn nano nginx epel-release postgresql postgresql-server -y
#
sudo postgresql-setup initdb
#
sudo chkconfig postgresql on
#
sudo sed -i 's+host    all             all             127.0.0.1/32            ident+host    all             all             127.0.0.1/32            trust+g' /var/lib/pgsql/data/pg_hba.conf
sudo sed -i 's+host    all             all             ::1/128                 ident+host    all             all             ::1/128                 trust+g' /var/lib/pgsql/data/pg_hba.conf
#
sudo service postgresql restart
#
cd /tmp
#
# Change your sql database password here, do not modify user.
#
sudo -u postgres psql -c "CREATE DATABASE onlyoffice;"
sudo -u postgres psql -c "CREATE USER onlyoffice WITH password 'onlyoffice';"
sudo -u postgres psql -c "GRANT ALL privileges ON DATABASE onlyoffice TO onlyoffice;"
#
sudo yum install redis rabbitmq-server -y
#
sudo service redis start
sudo systemctl enable redis
#
sudo service rabbitmq-server start
sudo systemctl enable rabbitmq-server
#
sudo yum install https://download.onlyoffice.com/repo/centos/main/noarch/onlyoffice-repo.noarch.rpm -y
#
sudo yum install onlyoffice-documentserver-ie -y
#
sudo service supervisord start
sudo systemctl enable supervisord
#
sudo systemctl enable nginx
sudo chkconfig nginx on
#
sudo service nginx stop
#
#
sudo mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.default
#
sudo echo "user                  nginx;

worker_processes      1;

error_log             /var/log/nginx/error.log warn;

pid                   /var/run/nginx.pid;

events {

  worker_connections  1024;

}

http {

  include             /etc/nginx/mime.types;

  default_type        application/octet-stream;

  log_format          main  '$remote_addr - $remote_user [$time_local] "$request" '

                            '$status $body_bytes_sent "$http_referer" '

                            '"$http_user_agent" "$http_x_forwarded_for"';

  access_log          /var/log/nginx/access.log  main;

  sendfile            on;

  #tcp_nopush         on;

  keepalive_timeout   65;

  #gzip               on;

  include             /etc/nginx/conf.d/*.conf;

}
" >> /etc/nginx/nginx.conf
#
# Don't forget to edit empty cert files and add cert data.
sudo mkdir /etc/sslcerts
# Put CA_Bundle cert and domain cert here (combined)
sudo touch /etc/sslcerts/certificate_bundle.crt
# Put your private key here
sudo touch /etc/sslcerts/private.key
#
# Add Certificate + CA_Bundle data here... yes I know, but i'm lazy. :-) 
#
#echo "---BIGIN CERTIFICATE----
# bla bla bla bla cert
# bla bla bla bla cert line 2
# bla bla bla bla cert line 3 
#---END CERTIFICATE---" >> /etc/sslcerts/certificate_bundle.crt
#
#echo "---BIGIN CERTIFICATE----
# bla bla bla bla cert
# bla bla bla bla cert line 2
# bla bla bla bla cert line 3 
#---END CERTIFICATE---" >> /etc/sslcerts/private.key
#
#
sudo sed -i 's+read -e -p "Host: " -i "$DB_HOST" DB_HOST+DB_HOST="localhost"+g' /bin/documentserver-configure.sh
sudo sed -i 's+read -e -p "Database name: " -i "$DB_NAME" DB_NAME+DB_NAME="onlyoffice"+g' /bin/documentserver-configure.sh
sudo sed -i 's+read -e -p "User: " -i "$DB_USER" DB_USER+DB_USER="onlyoffice"+g' /bin/documentserver-configure.sh
sudo sed -i 's+read -e -p "Password: " -s DB_PWD+DB_PWD="onlyoffice"+g' /bin/documentserver-configure.sh
#
sudo sed -i 's+read -e -p "Host: " -i "$REDIS_HOST" REDIS_HOST+REDIS_HOST="localhost"+g' /bin/documentserver-configure.sh
#
sudo sed -i 's+read -e -p "Host: " -i "$AMQP_SERVER_HOST_PORT_PATH" AMQP_SERVER_HOST_PORT_PATH+AMQP_SERVER_HOST_PORT_PATH="localhost"+g' /bin/documentserver-configure.sh
sudo sed -i 's+read -e -p "User: " -i "$AMQP_SERVER_USER" AMQP_SERVER_USER+AMQP_SERVER_USER="guest"+g' /bin/documentserver-configure.sh
sudo sed -i 's+read -e -p "Password: " -s AMQP_SERVER_PWD+AMQP_SERVER_PWD="guest"+g' /bin/documentserver-configure.sh
#
sudo bash documentserver-configure.sh
#
# "IMPORTANT" Leave this last for SSL enjoyment :-) documentserver-configure.sh will mess big time with ds.conf :-(
#
FILE=/etc/onlyoffice/documentserver/nginx/ds.conf
if [ -f "$FILE" ]; then
    rm -f $FILE
fi
#
sudo cp -f /etc/onlyoffice/documentserver/nginx/ds-ssl.conf.tmpl /etc/onlyoffice/documentserver/nginx/ds.conf
#
sudo sed -i 's+ssl_certificate {{SSL_CERTIFICATE_PATH}};+ssl_certificate /etc/sslcerts/certificate_bundle.crt;+g' /etc/onlyoffice/documentserver/nginx/ds.conf
sudo sed -i 's+ssl_certificate_key {{SSL_KEY_PATH}};+ssl_certificate_key /etc/sslcerts/private.key;+g' /etc/onlyoffice/documentserver/nginx/ds.conf
#
sudo sed -i 's+"visibilityTimeout": 300,+"visibilityTimeout": 30000,+g' /etc/onlyoffice/documentserver/default.json
#
chmod 664 /etc/onlyoffice/documentserver/local.json
chmod 664 /etc/onlyoffice/documentserver/production-linux.json
chmod 664 /etc/onlyoffice/documentserver/default.json
#
# "IMPORTANT" Do not uncomment if you are not embedding your SSL certificates to the script.
# You will need to start the service manually after the certs data are added to certificate_bundle.crt and private.key files.
#
#sudo service nginx start
#
sudo firewall-cmd --zone=public --add-port=443/tcp --permanent
sudo firewall-cmd --zone=public --add-port=80/tcp --permanent
sudo firewall-cmd --reload
#
sudo sed -i 's+SELINUX=enforcing+SELINUX=disabled+g' /etc/selinux/config
#
## To run demo (30) days comment out the line below.
sudo touch /var/www/onlyoffice/Data/license.lic
#
# Uncomment to add license string in between "" 
# sudo echo "" >> /var/www/onlyoffice/Data/license.lic
#
sudo supervisorctl restart all
#
# Cleaning up...
#
sudo sed -i 's+DB_HOST="localhost"+read -e -p "Host: " -i "$DB_HOST" DB_HOST+g' /bin/documentserver-configure.sh
sudo sed -i 's+DB_NAME="onlyoffice"+read -e -p "Database name: " -i "$DB_NAME" DB_NAME+g' /bin/documentserver-configure.sh
sudo sed -i 's+DB_USER="onlyoffice"+read -e -p "User: " -i "$DB_USER" DB_USER+g' /bin/documentserver-configure.sh
sudo sed -i 's+DB_PWD="onlyoffice"+read -e -p "Password: " -s DB_PWD+g' /bin/documentserver-configure.sh
#
sudo sed -i 's+REDIS_HOST="localhost"+read -e -p "Host: " -i "$REDIS_HOST" REDIS_HOST+g' /bin/documentserver-configure.sh
#
sudo sed -i 's+AMQP_SERVER_HOST_PORT_PATH="localhost"+read -e -p "Host: " -i "$AMQP_SERVER_HOST_PORT_PATH" AMQP_SERVER_HOST_PORT_PATH+g' /bin/documentserver-configure.sh
sudo sed -i 's+AMQP_SERVER_USER="guest"+read -e -p "User: " -i "$AMQP_SERVER_USER" AMQP_SERVER_USER+g' /bin/documentserver-configure.sh
sudo sed -i 's+AMQP_SERVER_PWD="guest"+read -e -p "Password: " -s AMQP_SERVER_PWD+g' /bin/documentserver-configure.sh
#
unset DB_HOST DB_NAME DB_USER DB_PWD REDIS_HOST AMQP_SERVER_HOST_PORT_PATH AMQP_SERVER_USER AMQP_SERVER_PWD
