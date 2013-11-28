#!/bin/bash
set -e

cd ~
apt-get update
apt-get install -y --force-yes openjdk-7-jre-headless rubygems ruby1.9.1-dev libcurl4-openssl-dev git apache2

# Install Elasticsearch
cd /opt
wget http://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-0.20.2.deb
dpkg -i elasticsearch-0.20.2.deb

sed -i '$a\cluster.name: default-cluster' /etc/elasticsearch/elasticsearch.yml
sed -i '$a\node.name: "elastic-master"' /etc/elasticsearch/elasticsearch.yml
sed -i '$a\discovery.zen.ping.multicast.enabled: false' /etc/elasticsearch/elasticsearch.yml
sed -i '$a\discovery.zen.ping.unicast.hosts: ["127.0.0.1:[9300-9400]"]' /etc/elasticsearch/elasticsearch.yml
sed -i '$a\node.master: true' /etc/elasticsearch/elasticsearch.yml
sed -i '$a\node.data: true' /etc/elasticsearch/elasticsearch.yml
sed -i '$a\index.number_of_shards: 1' /etc/elasticsearch/elasticsearch.yml
sed -i '$a\index.number_of_replicas: 0' /etc/elasticsearch/elasticsearch.yml
sed -i '$a\bootstrap.mlockall: true' /etc/elasticsearch/elasticsearch.yml
service elasticsearch restart

# Install Logstash 
mkdir /opt/logstash
cd /opt/logstash
wget https://download.elasticsearch.org/logstash/logstash/logstash-1.2.2-flatjar.jar
mv logstash-*.jar logstash.jar

# Create Logstash Init Script
(
cat <<'EOF'
#! /bin/sh
 
### BEGIN INIT INFO
# Provides:          logstash
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start daemon at boot time
# Description:       Enable service provided by daemon.
### END INIT INFO
 
. /lib/lsb/init-functions
 
name="logstash"
logstash_bin="/usr/bin/java -- -jar /opt/logstash/logstash.jar"
logstash_conf="/etc/logstash/logstash.conf"
logstash_log="/var/log/logstash.log"
pid_file="/var/run/$name.pid"
 
start () {
        command="${logstash_bin} agent -f $logstash_conf --log ${logstash_log}"
 
        log_daemon_msg "Starting $name" "$name"
        if start-stop-daemon --start --quiet --oknodo --pidfile "$pid_file" -b -m --exec $command; then
                log_end_msg 0
        else
                log_end_msg 1
        fi
}
 
stop () {
        log_daemon_msg "Stopping $name" "$name"
        start-stop-daemon --stop --quiet --oknodo --pidfile "$pid_file"
}
 
status () {
        status_of_proc -p $pid_file "" "$name"
}
 
case $1 in
        start)
                if status; then exit 0; fi
                start
                ;;
        stop)
                stop
                ;;
        reload)
                stop
                start
                ;;
        restart)
                stop
                start
                ;;
        status)
                status && exit 0 || exit $?
                ;;
        *)
                echo "Usage: $0 {start|stop|restart|reload|status}"
                exit 1
                ;;
esac
 
exit 0
EOF
) | tee /etc/init.d/logstash
chmod +x /etc/init.d/logstash
update-rc.d logstash defaults

# Create Logstash configuration file
mkdir /etc/logstash
tee -a /etc/logstash/logstash.conf <<EOF
input {
udp {
type => "syslog"
port => "514"
}
}

output {
elasticsearch_http {
host => "127.0.0.1"
flush_size => 1
}
}
EOF

service logstash restart

# Install and configure the Kibana frontend
cd /var/www
wget https://download.elasticsearch.org/kibana/kibana/kibana-3.0.0milestone4.tar.gz
tar zxvf kibana-*
rm kibana-*.tar.gz
mv kibana-* kibana

echo "Connect to http://hostname|ip/kibana"
