#!/bin/bash

# Parameter
export TOMCAT_DOWNLOAD_URL="https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.100/bin/apache-tomcat-9.0.100.tar.gz"
export JAVA_VERSION="11"
# Java Version e.g., : 1.8.0, 11, 17, 21, 22
export DIRECTORY_NAME="xxxx"

# Add tomcat user
useradd tomcat
chage -m 0 -M 99999 tomcat

# Ownership Setting
chown -R tomcat:tomcat /$DIRECTORY_NAME

# Get Filename
export TOMCAT_FILENAME=`echo $TOMCAT_DOWNLOAD_URL | grep -o '[^/]*$'`

# Download
wget -O /$DIRECTORY_NAME/$TOMCAT_FILENAME $TOMCAT_DOWNLOAD_URL
tar zxvf /$DIRECTORY_NAME/$TOMCAT_FILENAME -C /$DIRECTORY_NAME

# Remove .tar.gz in Filename
export TOMCAT_FILENAME_REMOVE_TARGZ=`echo $TOMCAT_FILENAME | awk -F "tar" '{ print $1 }' | rev | cut -c 2- | rev`

export TOMCAT_HOME="/$DIRECTORY_NAME/$TOMCAT_FILENAME_REMOVE_TARGZ"

# Block root user
sed -i '2i\# Block ROOT user for start-up' $TOMCAT_HOME/bin/startup.sh
sed -i '3i\if [ "tomcat" != \`whoami\` ]; then' $TOMCAT_HOME/bin/startup.sh
sed -i '4i\    echo \"You must run this script with tomcat account. Exit with Error.\"' $TOMCAT_HOME/bin/startup.sh
sed -i '5i\    exit -1' $TOMCAT_HOME/bin/startup.sh
sed -i '6i\fi' $TOMCAT_HOME/bin/startup.sh

# YUM Install
export JAVA_PACKAGE_01="java-$JAVA_VERSION-amazon-corretto.x86_64"
export JAVA_PACKAGE_02="java-$JAVA_VERSION-amazon-corretto-devel.x86_64"
yum install -y $JAVA_PACKAGE_01 $JAVA_PACKAGE_02


# Add JAVA_HOME /etc/bashrc
sed -i '/JAVA_HOME/d' /etc/bashrc
echo "" >> /etc/bashrc
echo "# Added JAVA_HOME on `date +%Y-%m-%d`" >> /etc/bashrc
echo "JAVA_HOME=/usr/lib/jvm/java-$JAVA_VERSION-openjdk" >> /etc/bashrc
echo "export JAVA_HOME" >> /etc/bashrc
echo "PATH=\${JAVA_HOME}/bin:\$PATH" >> /etc/bashrc

# Log Rotate
echo "$TOMCAT_HOME/logs/catalina.out {" > /etc/logrotate.d/tomcat
echo "  copytruncate" >> /etc/logrotate.d/tomcat
echo "  daily" >> /etc/logrotate.d/tomcat
echo "  rotate 10" >> /etc/logrotate.d/tomcat
echo "  compress" >> /etc/logrotate.d/tomcat
echo "  missingok" >> /etc/logrotate.d/tomcat
echo "  notifempty" >> /etc/logrotate.d/tomcat
echo "  create 0644 tomcat tomcat" >> /etc/logrotate.d/tomcat
echo "}" >> /etc/logrotate.d/tomcat

# Add JVM Memory Size
sed -i '2i\JAVA_OPTS="$JAVA_OPTS -Xms700m -Xmx700m"' $TOMCAT_HOME/bin/catalina.sh

# Remove comments in XML files
sed '/<!--/,/-->/d' $1 $TOMCAT_HOME/conf/server.xml > a1.txt
cat a1.txt > $TOMCAT_HOME/conf/server.xml
rm a1.txt

# Auto Start
echo "[Unit]" > /etc/systemd/system/tomcat.service
echo "Description=Tomcat restart" >> /etc/systemd/system/tomcat.service
echo "After=syslog.target network.target" >> /etc/systemd/system/tomcat.service
echo "" >> /etc/systemd/system/tomcat.service
echo "[Service]" >> /etc/systemd/system/tomcat.service
echo "Type=forking" >> /etc/systemd/system/tomcat.service
echo "" >> /etc/systemd/system/tomcat.service
echo "ExecStart=$TOMCAT_HOME/bin/startup.sh" >> /etc/systemd/system/tomcat.service
echo "ExecStop=$TOMCAT_HOME/bin/shutdown.sh" >> /etc/systemd/system/tomcat.service
echo "" >> /etc/systemd/system/tomcat.service
echo "User=tomcat" >> /etc/systemd/system/tomcat.service
echo "Group=tomcat" >> /etc/systemd/system/tomcat.service
echo "" >> /etc/systemd/system/tomcat.service
echo "[Install]" >> /etc/systemd/system/tomcat.service
echo "WantedBy=multi-user.target" >> /etc/systemd/system/tomcat.service

chmod 755 /etc/systemd/system/tomcat.service
chown tomcat:tomcat -R /$DIRECTORY_NAME
systemctl enable tomcat.service
systemctl stop tomcat.service
systemctl start tomcat.service
systemctl status tomcat.service

# Shell Script for Start, Stop, Tail
echo '#!/bin/bash' > /root/tail.sh
echo "tail -f $TOMCAT_HOME/logs/catalina.out" >> /root/tail.sh

echo '#!/bin/bash' > /root/start.sh
echo "systemctl start tomcat" >> /root/start.sh

echo '#!/bin/bash' > /root/stop.sh
echo "systemctl stop tomcat" >> /root/stop.sh

echo '#!/bin/bash' > /root/restart.sh
echo "systemctl restart tomcat" >> /root/restart.sh

echo '#!/bin/bash' > /root/status.sh
echo "systemctl status tomcat" >> /root/status.sh

chmod 755 /root/*sh
