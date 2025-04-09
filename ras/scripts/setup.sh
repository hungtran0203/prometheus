#!/bin/bash

sudo apt install curl git
sudo apt-get install openssl
sudo apt-get install openssl-dev

sudo apt-get install libssl
sudo apt-get install libssl-dev

sudo apt install libedit-dev
sudo apt install libncurses5-dev

sudo apt-get install build-essential tk-dev libncurses5-dev libncursesw5-dev libreadline6-dev libdb5.3-dev libgdbm-dev libsqlite3-dev libssl-dev libbz2-dev libexpat1-dev liblzma-dev zlib1g-dev libffi-dev

sudo apt-get install python3-picamera
# sudo pip3 install --upgrade picamera[array]

# https://raspberrypi-guide.github.io/electronics/using-usb-webcams
sudo apt install fswebcam
sudo apt install ffmpeg

# fswebcam -r 1280x720 --no-banner /images/image1.jpg

# v4l2-ctl --list-formats

# sudo apt install cmake


# export LD_LIBRARY_PATH=.
# ./mjpg_streamer -o "output_http.so -w ./www" -i "input_raspicam.so"


curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

wget https://releases.hashicorp.com/nomad/1.7.5/nomad_1.7.5_linux_arm64.zip
unzip nomad_1.7.5_linux_arm64.zip
sudo install nomad /usr/local/bin/

# asdf

git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.1
. "$HOME/.asdf/asdf.sh"


asdf plugin-add java https://github.com/halcyon/asdf-java.git
asdf install java latest

asdf plugin-add rust https://github.com/asdf-community/asdf-rust.git
asdf install rust latest

asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
asdf install nodejs latest

asdf plugin-add python
asdf install python latest

asdf plugin add golang https://github.com/asdf-community/asdf-golang.git
asdf install golang latest

asdf plugin add dotnet
asdf install dotnet latest



scp -i ~/.ssh/id_rsa nomad/config/clients/ras.hcl hung@ras.local:/etc/nomad.d/client.hcl