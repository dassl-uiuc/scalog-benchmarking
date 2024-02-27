#! /bin/bash

cd ~
sudo apt update

# install go
wget https://go.dev/dl/go1.22.0.linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> .bashrc
export PATH=$PATH:/usr/local/go/bin

# install goreman
git clone https://github.com/mattn/goreman.git
cd goreman
go build
sudo mv goreman /usr/local/bin