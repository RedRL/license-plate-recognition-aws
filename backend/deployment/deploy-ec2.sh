#!/bin/bash
set -e

echo "Provisioning EC2 for License Plate Recognition..."

# Update system and install basics
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y build-essential python3 python3-pip wget tar unzip

# Install MySQL client (for DB connectivity if needed)
sudo apt-get install -y mysql-client

# Install OpenALPR engine (Community Edition for Ubuntu 18.04)
cd /tmp
wget https://github.com/openalpr/openalpr/releases/download/v2.3.0/openalpr-2.3.0-ubuntu-18.04.tar.gz
tar xzf openalpr-2.3.0-ubuntu-18.04.tar.gz
cd openalpr-2.3.0-ubuntu-18.04
sudo ./install.sh

# Add OpenALPR to PATH for all sessions
echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bashrc
source ~/.bashrc

# Install Python dependencies
pip3 install --upgrade pip
pip3 install -r /home/ubuntu/LicensePlateRecognitionProject/backend/requirements.txt

echo "EC2 setup complete: OpenALPR and Python wrapper installed."
