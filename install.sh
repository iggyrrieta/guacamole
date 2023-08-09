#!/bin/bash


# COLORS
COLOR_GREEN='\033[1;32m'
COLOR_BLUE='\033[1;34m'
NOCOLOR='\033[0m'

# Script path
SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# Arch
ARCH=$(dpkg --print-architecture)

echo -e "\n${COLOR_BLUE}=========================================="
echo -e "             INSTALL TOMCAT + GUACAMOLE                  "
echo -e "==========================================${NOCOLOR}\n"

echo "Process:"
echo "1 - Requirements"
echo "2 - OpenSSL"
echo "3 - TigerVNC"
echo "4 - Tomcat"
echo "5 - Guacamole"

echo -e "\n${COLOR_BLUE}=========================================="
echo -e "     1- Requirements                          "
echo -e "==========================================${NOCOLOR}\n"

echo -e "${COLOR_GREEN}Installing requirements...${NOCOLOR}\n"
sudo apt install -y ssh gcc nano vim curl wget g++ libcairo2-dev libjpeg-turbo8-dev libpng-dev libtool-bin libossp-uuid-dev \
libavcodec-dev  libavformat-dev libavutil-dev libswscale-dev build-essential libpango1.0-dev libssh2-1-dev libvncserver-dev \
libtelnet-dev libpulse-dev libvorbis-dev libwebp-dev

echo -e "\n${COLOR_GREEN}Installing freeRDP2....${NOCOLOR}\n"
sudo add-apt-repository ppa:remmina-ppa-team/remmina-next-daily -y
sudo apt update
sudo apt install freerdp2-dev freerdp2-x11 -y

echo -e "\n${COLOR_GREEN}Installing ubuntu graphics...${NOCOLOR}\n"
sudo apt install xfce4 xfce4-goodies -y
sudo systemctl set-default graphical -y

echo -e "\n${COLOR_BLUE}=========================================="
echo -e "     2- OpenSSL                            "
echo -e "==========================================${NOCOLOR}\n"

cd ${SCRIPTPATH}/openssl-1.1.1l/

./config
make
sudo make install
sudo cp /usr/local/bin/openssl /usr/bin
sudo ldconfig

echo -e "\n${COLOR_BLUE}=========================================="
echo -e "     3- TigerVNC                            "
echo -e "==========================================${NOCOLOR}\n"

sudo apt install tigervnc-standalone-server -y

echo -e "\n${COLOR_GREEN}Creating new computer user named 'vncuser'...${NOCOLOR}\n"
sudo useradd -m -s /bin/bash vncuser
sudo chpasswd <<<"vncuser:1"
sudo usermod -aG sudo vncuser

echo -e "\n${COLOR_GREEN}Setting vnc folder and configs...${NOCOLOR}"
mkdir -p ~/.vnc
sudo chmod -R 777 ~/.vnc
touch ~/.vnc/xstartup
touch ~/.vnc/config

echo '#!/bin/sh' > ~/.vnc/xstartup
echo '# Start up the standard system desktop' >> ~/.vnc/xstartup
echo 'unset SESSION_MANAGER' >> ~/.vnc/xstartup
echo 'unset DBUS_SESSION_BUS_ADDRESS' >> ~/.vnc/xstartup
echo '/usr/bin/startxfce4' >> ~/.vnc/xstartup
echo '[ -x /etc/vnc/xstartup ] && exec /etc/vnc/xstartup' >> ~/.vnc/xstartup
echo '[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources' >> ~/.vnc/xstartup
echo 'x-window-manager &' >> ~/.vnc/xstartup

echo 'geometry=1024x768' > ~/.vnc/config
echo 'dpi=96' >> ~/.vnc/config
echo 'depth=24' >> ~/.vnc/config

sudo mkdir -p /etc/tigervnc
sudo chmod -R 777 /etc/tigervnc
touch /etc/tigervnc/vncserver.users
echo '# tigervnc users:' > /etc/tigervnc/vncserver.users
echo ':1=vncuser' >> /etc/tigervnc/vncserver.users

echo -e "\n${COLOR_GREEN}Crear servicio tigerVNC...${NOCOLOR}\n"
sudo touch /etc/systemd/system/vncserver@.service
sudo chmod 777 /etc/systemd/system/vncserver@.service

echo '[Unit]' > /etc/systemd/system/vncserver@.service
echo 'Description=Remote desktop service (VNC)' >> /etc/systemd/system/vncserver@.service
echo 'After=syslog.target network.target' >> /etc/systemd/system/vncserver@.service
echo '' >> /etc/systemd/system/vncserver@.service
echo '[Service]' >> /etc/systemd/system/vncserver@.service
echo 'Type=simple' >> /etc/systemd/system/vncserver@.service
echo 'User=vncuser' >> /etc/systemd/system/vncserver@.service
echo 'PAMName=login' >> /etc/systemd/system/vncserver@.service
echo 'PIDFile=/home/%u/.vnc/%H%i.pid' >> /etc/systemd/system/vncserver@.service
echo 'ExecStartPre=/bin/sh -c '/usr/bin/vncserver -kill :%i > /dev/null 2>&1 || :'' >> /etc/systemd/system/vncserver@.service
echo 'ExecStart=/usr/bin/vncserver :%i -geometry 1440x900 -alwaysshared -fg' >> /etc/systemd/system/vncserver@.service
echo 'ExecStop=/usr/bin/vncserver -kill :%i' >> /etc/systemd/system/vncserver@.service
echo '' >> /etc/systemd/system/vncserver@.service
echo '[Install]' >> /etc/systemd/system/vncserver@.service
echo 'WantedBy=multi-user.target' >> /etc/systemd/system/vncserver@.service

sudo systemctl daemon-reload
sudo systemctl start vncserver@1.service
sudo systemctl enable vncserver@1.service

sudo ufw allow 5901:5910/tcp
sudo ufw reload

echo "\n${COLOR_GREEN}Set VNC password (6 characters):${NOCOLOR}\n" 
su - vncuser
vncpasswd
exit
vncserver

echo -e "\n${COLOR_BLUE}=========================================="
echo -e "     4- Tomcat                           "
echo -e "==========================================${NOCOLOR}\n"

echo -e "${COLOR_GREEN}Installing requirements tomcat...${NOCOLOR}\n"
sudo apt install openjdk-17-jdk -y
if getent passwd tomcat > /dev/null 2>&1; then
    echo "Tomcat user already exists..."
else
    sudo useradd -m -U -d /opt/tomcat -s /bin/false tomcat
fi

sudo mkdir -p /opt/tomcat
sudo tar -xzf ${SCRIPTPATH}/tomcat-9.0.70/apache-tomcat-9.0.70.tar.gz -C /opt/tomcat/
sudo mv /opt/tomcat/apache-tomcat-9.0.70 /opt/tomcat/tomcatapp
sudo chmod -R 777 /opt/tomcat
sudo find /opt/tomcat/tomcatapp/bin/ -type f -iname "*.sh" -exec chmod +x {} \;

echo -e "${COLOR_GREEN}Creating tomcat service...${NOCOLOR}\n"
sudo touch /etc/systemd/system/tomcat.service
sudo chmod 777 /etc/systemd/system/tomcat.service

echo '[Unit]' > /etc/systemd/system/tomcat.service
echo 'Description=Tomcat 9 servlet container' >> /etc/systemd/system/tomcat.service
echo 'After=network.target' >> /etc/systemd/system/tomcat.service
echo '' >> /etc/systemd/system/tomcat.service
echo '[Service]' >> /etc/systemd/system/tomcat.service
echo 'Type=forking' >> /etc/systemd/system/tomcat.service
echo '' >> /etc/systemd/system/tomcat.service
echo 'User=tomcat' >> /etc/systemd/system/tomcat.service
echo 'Group=tomcat' >> /etc/systemd/system/tomcat.service
echo '' >> /etc/systemd/system/tomcat.service
echo 'Environment="JAVA_HOME=/usr/lib/jvm/java-17-openjdk-'${ARCH}'"' >> /etc/systemd/system/tomcat.service
echo "Environment='JAVA_OPTS=-Djava.security.egd=file:///dev/urandom -Djava.awt.headless=true'" >> /etc/systemd/system/tomcat.service
echo '' >> /etc/systemd/system/tomcat.service
echo "Environment='CATALINA_BASE=/opt/tomcat/tomcatapp'" >> /etc/systemd/system/tomcat.service
echo "Environment='CATALINA_HOME=/opt/tomcat/tomcatapp'" >> /etc/systemd/system/tomcat.service
echo "Environment='CATALINA_PID=/opt/tomcat/tomcatapp/temp/tomcat.pid'" >> /etc/systemd/system/tomcat.service
echo "Environment='CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC'" >> /etc/systemd/system/tomcat.service
echo '' >> /etc/systemd/system/tomcat.service
echo 'ExecStart=/opt/tomcat/tomcatapp/bin/startup.sh' >> /etc/systemd/system/tomcat.service
echo 'ExecStop=/opt/tomcat/tomcatapp/bin/shutdown.sh' >> /etc/systemd/system/tomcat.service
echo '' >> /etc/systemd/system/tomcat.service
echo '[Install]' >> /etc/systemd/system/tomcat.service
echo 'WantedBy=multi-user.target' >> /etc/systemd/system/tomcat.service

sudo systemctl daemon-reload
sudo systemctl enable --now tomcat
sudo ufw allow 8080/tcp

echo -e "\n${COLOR_BLUE}=========================================="
echo -e "     5- Guacamole                           "
echo -e "==========================================${NOCOLOR}\n"

sudo apt install -y build-essential libcairo2-dev libjpeg-turbo8-dev \
    libpng-dev libtool-bin libossp-uuid-dev libvncserver-dev \
    freerdp2-dev libssh2-1-dev libtelnet-dev libwebsockets-dev \
    libpulse-dev libvorbis-dev libwebp-dev libssl-dev \
    libpango1.0-dev libswscale-dev libavcodec-dev libavutil-dev \
    libavformat-dev
    
cd ${SCRIPTPATH}/guacamole-server-1.4.0/

echo "${COLOR_GREEN}Building guacamole 1.4.0...${NOCOLOR}\n"
./configure --disable-guacenc --with-init-dir=/etc/init.d

make
sudo make install
sudo ldconfig
sudo systemctl daemon-reload
sudo systemctl start guacd
sudo systemctl enable guacd

sudo mkdir -p /etc/guacamole
sudo chmod -R 777 /etc/guacamole
sudo cp ${SCRIPTPATH}/guacamole-client-1.4.0/guacamole-1.4.0.war /etc/guacamole/guacamole.war
sudo ln -sf /etc/guacamole/guacamole.war /opt/tomcat/tomcatapp/webapps/
sudo touch /etc/guacamole/guacamole.properties
sudo chmod 777 /etc/guacamole/guacamole.properties
sudo chmod -R 777 /opt/tomcat/tomcatapp/webapps/guacamole

# No-auth extension:
sudo cp ${SCRIPTPATH}/guacamole-auth-noauth-1.4.0/guacamole-auth-noauth-1.4.0.jar /opt/tomcat/tomcatapp/webapps/guacamole/WEB-INF/lib/
sudo cp ${SCRIPTPATH}/guacamole-auth-noauth-1.4.0/guacamole-auth-noauth-1.4.0.jar /etc/guacamole/extensions/
sudo touch /etc/guacamole/noauth-config.xml
sudo chmod 777 /etc/guacamole/noauth-config.xml
echo '<configs>' > /etc/gacamole/noauth-config.xml
echo '  <config name="vnc-free-access" protocol="vnc">' > /etc/guacamole/noauth-config.xml
echo '    <param name="hostname" value="localhost" />' > /etc/guacamole/noauth-config.xml
echo '    <param name="port" value="5901" />' > /etc/guacamole/noauth-config.xml
echo '    <param name="password" value="YOUR VNC USER COMPUTER PASSWORD HERE" />' > /etc/guacamole/noauth-config.xml
echo '  </config>' > /etc/guacamole/noauth-config.xml
echo '</configs>' > /etc/guacamole/noauth-config.xml

echo 'guacd-hostname: localhost' > /etc/guacamole/guacamole.properties
echo 'guacd-port:     4822' >> /etc/guacamole/guacamole.properties
echo ' ' >> /etc/guacamole/guacamole.properties
echo '#UNCOMMENT THE FOLLOWING TO USE AUTH SYSTEM' >> /etc/guacamole/guacamole.properties
echo '#------------------------------------------' >> /etc/guacamole/guacamole.properties
echo 'user-mapping:   /etc/guacamole/user-mapping.xml' >> /etc/guacamole/guacamole.properties
echo 'auth-provider:   net.sourceforge.guacamole.net.basic.BasicFileAuthenticationProvider' >> /etc/guacamole/guacamole.properties
echo ' ' >> /etc/guacamole/guacamole.properties
echo '#UNCOMMENT THE FOLLOWING TO NOT USING AUTH SYSTEM' >> /etc/guacamole/guacamole.properties
echo '#------------------------------------------------' >> /etc/guacamole/guacamole.properties
echo '#auth-provider: net.sourceforge.guacamole.net.auth.noauth.NoAuthenticationProvider' >> /etc/guacamole/guacamole.properties
echo '#noauth-config: /etc/guacamole/noauth-config.xml' >> /etc/guacamole/guacamole.properties

sudo ln -sf /etc/guacamole /opt/tomcat/tomcatapp/.guacamole 

sudo touch /etc/guacamole/user-mapping.xml
sudo chmod 777 /etc/guacamole/user-mapping.xml

echo '<user-mapping> ' > /etc/guacamole/user-mapping.xml
echo '' >> /etc/guacamole/user-mapping.xml
echo '    <!-- Per-user authentication and config information -->' >> /etc/guacamole/user-mapping.xml
echo '' >> /etc/guacamole/user-mapping.xml
echo '    <!-- A user using md5 to hash the password' >> /etc/guacamole/user-mapping.xml
echo '         guacadmin user and its md5 hashed password below is used to ' >> /etc/guacamole/user-mapping.xml
echo '             login to Guacamole Web UI-->' >> /etc/guacamole/user-mapping.xml
echo '             ' >> /etc/guacamole/user-mapping.xml
echo '             ' >> /etc/guacamole/user-mapping.xml
echo '    <!-- FIRST USER -->' >> /etc/guacamole/user-mapping.xml
echo '    <authorize ' >> /etc/guacamole/user-mapping.xml
echo '           username="vncuser"' >> /etc/guacamole/user-mapping.xml
echo '           password="c4ca4238a0b923820dcc509a6f75849b"' >> /etc/guacamole/user-mapping.xml
echo '           encoding="md5">' >> /etc/guacamole/user-mapping.xml
echo '' >> /etc/guacamole/user-mapping.xml
echo '        <!-- First authorized Remote connection -->' >> /etc/guacamole/user-mapping.xml
echo '        <connection name="SSH connection">' >> /etc/guacamole/user-mapping.xml
echo '            <protocol>ssh</protocol>' >> /etc/guacamole/user-mapping.xml
echo '            <param name="hostname">localhost</param>' >> /etc/guacamole/user-mapping.xml
echo '            <param name="port">22</param>' >> /etc/guacamole/user-mapping.xml
echo '        </connection>' >> /etc/guacamole/user-mapping.xml
echo '	<connection name="VNC connection">' >> /etc/guacamole/user-mapping.xml
echo '	   <protocol>vnc</protocol>' >> /etc/guacamole/user-mapping.xml
echo '	   <param name="hostname">localhost</param>' >> /etc/guacamole/user-mapping.xml
echo '	   <param name="port">5901</param>' >> /etc/guacamole/user-mapping.xml
echo '	</connection>' >> /etc/guacamole/user-mapping.xml
echo '' >> /etc/guacamole/user-mapping.xml
echo '    </authorize>' >> /etc/guacamole/user-mapping.xml
echo ' ' >> /etc/guacamole/user-mapping.xml
echo '' >> /etc/guacamole/user-mapping.xml
echo '</user-mapping>' >> /etc/guacamole/user-mapping.xml

sudo systemctl restart tomcat guacd


echo -e "\n${COLOR_BLUE}The End...reboot computer to apply changes...${NOCOLOR}\n"
echo -e "\n\n${COLOR_BLUE}If you don't want to use password access, modify /etc/guacamole/guacamole.properties and /etc/guacamole/noauth-config.xml. Then restart tomcat.${NOCOLOR}\n\n"
