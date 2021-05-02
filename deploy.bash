#!/bin/bash
echo "This assumes that you are doing a green-field install.  If you're not, please exit in the next 15 seconds."
sleep 15
echo "Continuing install, this will prompt you for your password if you're not already running as root and you didn't enable passwordless sudo.  Please do not run me as root!"
if [[ `whoami` == "root" ]]; then
    echo "You ran me as root! Do not run me as root!"
    exit 1
fi
ROOT_SQL_PASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
CURUSER=$(whoami)
sudo timedatectl set-timezone Asia/Kuala_Lumpur
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $ROOT_SQL_PASS"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $ROOT_SQL_PASS"
echo -e "[client]\nuser=root\npassword=$ROOT_SQL_PASS" | sudo tee /root/.my.cnf
DEBIAN_FRONTEND=noninteractive sudo --preserve-env=DEBIAN_FRONTEND apt-get -y install libcap2-bin git python python-virtualenv python3-virtualenv curl ntp build-essential screen cmake pkg-config libboost-all-dev libevent-dev libunbound-dev libminiupnpc-dev libunwind8-dev liblzma-dev libldns-dev libexpat1-dev mysql-server lmdb-utils libzmq3-dev libsodium-dev libssl-dev libreadline6-dev libgtest-dev doxygen graphviz
cd /usr/src/gtest
sudo cmake .
sudo make
sudo mv libg* /usr/lib/
cd ~
git clone https://github.com/myashtree/nodejs-pool.git
sudo systemctl enable ntp
cd /usr/local/src
sudo git clone https://github.com/haven-protocol-org/haven-legacy.git
cd haven-legacy
sudo git checkout 3.2.2
sudo git submodule update --init
USE_SINGLE_BUILDDIR=1 sudo --preserve-env=USE_SINGLE_BUILDDIR make -j$(nproc) release || USE_SINGLE_BUILDDIR=1 sudo --preserve-env=USE_SINGLE_BUILDDIR make release || exit 0
sudo cp ~/nodejs-pool/deployment/haven.service /lib/systemd/system/
sudo useradd -m havendaemon -d /home/havendaemon
sudo systemctl daemon-reload
sudo systemctl enable haven
sudo systemctl start haven
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash
source ~/.nvm/nvm.sh
nvm install v8.9.3
nvm alias default v8.9.3
cd ~/nodejs-pool
npm install
npm install -g pm2
openssl req -subj "/C=IT/ST=Pool/L=Daemon/O=Mining Pool/CN=mining.pool" -newkey rsa:2048 -nodes -keyout cert.key -x509 -out cert.pem -days 36500
sudo mkdir ~/pool_db/
sed -r "s/(\"db_storage_path\": ).*/\1\"\/home\/$CURUSER\/pool_db\/\",/" config_example.json > config.json
cd ~
git clone https://github.com/mesh0000/poolui.git
cd poolui
npm install
./node_modules/bower/bin/bower update
./node_modules/gulp/bin/gulp.js build
cd build
sudo ln -s `pwd` /var/www
CADDY_DOWNLOAD_DIR=$(mktemp -d)
cd $CADDY_DOWNLOAD_DIR
curl -sL "https://github.com/caddyserver/caddy/releases/download/v0.11.5/caddy_v0.11.5_linux_amd64.tar.gz" | tar -xz caddy init/linux-systemd/caddy.service
sudo mv caddy /usr/local/bin
sudo chown root:root /usr/local/bin/caddy
sudo chmod 755 /usr/local/bin/caddy
sudo setcap 'cap_net_bind_service=+ep' /usr/local/bin/caddy
sudo mkdir /etc/caddy
sudo usermod -a -G www-data www-data
sudo chown -R root:www-data /etc/caddy
sudo mkdir /etc/ssl/caddy
sudo chown -R www-data:root /etc/ssl/caddy
sudo chmod 0770 /etc/ssl/caddy
sudo cp ~/nodejs-pool/deployment/caddyfile /etc/caddy/Caddyfile
sudo chown www-data:www-data /etc/caddy/Caddyfile
sudo chmod 444 /etc/caddy/Caddyfile
sudo sh -c "sed 's/ProtectHome=true/ProtectHome=false/' init/linux-systemd/caddy.service > /etc/systemd/system/caddy.service"
sudo chown root:root /etc/systemd/system/caddy.service
sudo chmod 644 /etc/systemd/system/caddy.service
sudo systemctl daemon-reload
sudo systemctl enable caddy.service
sudo systemctl start caddy.service
rm -rf $CADDY_DOWNLOAD_DIR
cd ~
source ~/.nvm/nvm.sh
sudo env PATH=$PATH:`pwd`/.nvm/versions/node/v8.9.3/bin `pwd`/.nvm/versions/node/v8.9.3/lib/node_modules/pm2/bin/pm2 startup systemd -u $CURUSER --hp `pwd`
cd ~/nodejs-pool
sudo chown -R $CURUSER. ~/.pm2
echo "Installing pm2-logrotate in the background!"
pm2 install pm2-logrotate &
pm2 start init.js --name=api --log-date-format="YYYY-MM-DD HH:mm Z" -- --module=api
bash ~/nodejs-pool/deployment/install_lmdb_tools.sh
echo "You're setup!  Please read the rest of the readme for the remainder of your setup and configuration.  These steps include: Setting your Fee Address, Pool Address, Global Domain, and the Mailgun setup!"
