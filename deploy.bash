#!/bin/bash
echo "This assumes that you are doing a green-field install.  If you're not, please exit in the next 15 seconds."
sleep 15
echo "Continuing install, this will prompt you for your password if you're not already running as root and you didn't enable passwordless sudo.  Please do not run me as root!"
if [[ `whoami` == "root" ]]; then
    echo "You ran me as root! Do not run me as root!"
    exit 1
fi
CURUSER=$(whoami)
sudo timedatectl set-timezone Etc/UTC
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install build-essential cmake pkg-config libboost-all-dev libssl-dev libzmq3-dev libunbound-dev libsodium-dev libunwind8-dev liblzma-dev libreadline6-dev libldns-dev libexpat1-dev doxygen graphviz libpgm-dev qttools5-dev-tools libhidapi-dev libusb-dev libprotobuf-dev protobuf-compiler
cd ~
git clone https://github.com/myashtree/equil.git nodejs-pool # Change this depending on how the deployment goes.
cd /usr/src/gtest
sudo cmake
sudo make
sudo mv libg* /usr/lib/
cd ~
cd /usr/local/src
sudo git clone https://github.com/EquilibriaCC/Equilibria.git
cd Equilibria
sudo git checkout v9.0.2
sudo git submodule update --init
sudo make -j$(nproc)
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.38.0/install.sh | bash
source ~/.nvm/nvm.sh
nvm install v11.15.0
cd ~/nodejs-pool
npm update
npm install -g pm2
cd ~
sudo env PATH=$PATH:`pwd`/.nvm/versions/node/v11.15.0/bin `pwd`/.nvm/versions/node/v11.15.0/lib/node_modules/pm2/bin/pm2 startup systemd -u $CURUSER --hp `pwd`
cd ~/nodejs-pool
sudo chown -R $CURUSER. ~/.pm2
echo "Installing pm2-logrotate in the background!"
pm2 install pm2-logrotate &
echo "You're setup!  Please read the rest of the readme for the remainder of your setup and configuration.  These steps include: Setting your Fee Address, Pool Address, Global Domain, and the Mailgun setup!"
