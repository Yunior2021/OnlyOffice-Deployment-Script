#!/bin/bash
#
sudo apt update
#
sudo apt install libstdc++6 libcurl3 libxml2 supervisor fonts-dejavu fonts-liberation \
ttf-mscorefonts-installer fonts-crosextra-carlito fonts-takao-gothic fonts-opensymbol \
postgresql redis-server rabbitmq-server nginx-extras -y
#
sudo -i -u postgres psql -c "CREATE DATABASE onlyoffice;"
sudo -i -u postgres psql -c "CREATE USER onlyoffice WITH password 'onlyoffice';"
sudo -i -u postgres psql -c "GRANT ALL privileges ON DATABASE onlyoffice TO onlyoffice;"
#
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys CB2DE8E5
#
sudo echo "deb https://download.onlyoffice.com/repo/debian squeeze main" | sudo tee /etc/apt/sources.list.d/onlyoffice.list
#
sudo apt-get update
#
# You will be asked to enter sql database password at some point during the onlyoffice installation.
# Please use "onlyoffice", unless you decided to change it.
#
sudo apt-get install onlyoffice-documentserver -y
#
sudo service nginx stop
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
FILE=/etc/onlyoffice/documentserver/nginx/ds.conf
if [ -f "$FILE" ]; then
    rm -f $FILE
fi
#
sudo cp -f /etc/onlyoffice/documentserver/nginx/ds-ssl.conf.tmpl /etc/onlyoffice/documentserver/nginx/ds.conf
#
sudo sed -i 's+ssl_certificate {{SSL_CERTIFICATE_PATH}};+ssl_certificate /etc/sslcerts/certificate.pem;+g' /etc/onlyoffice/documentserver/nginx/ds.conf
sudo sed -i 's+ssl_certificate_key {{SSL_KEY_PATH}};+ssl_certificate_key /etc/sslcerts/private.key;+g' /etc/onlyoffice/documentserver/nginx/ds.conf
#
sudo sed -i 's+"visibilityTimeout": 300,+"visibilityTimeout": 30000,+g' /etc/onlyoffice/documentserver/default.json
#
sudo supervisorctl restart all
#
#Uncomment only if your are embedding your certificates in the script.
#If not then you will have to start nginx service manually at a later time.
#
# sudo service nginx start
#
#Uncomment if having issues resolving dns to where your internal whatevername.yourdomain.local
#"IMPORTANT" your server hostname needs to be different to what your domain would be. 
#
# iname=$(ip -o link show | sed -rn '/^[0-9]+: en/{s/.: ([^:]*):.*/\1/p}')
# sudo systemd-resolve --flush-caches
# sudo systemd-resolve -i $iname --set-dns 192.168.10.1 --set-domain yourdomain.local
