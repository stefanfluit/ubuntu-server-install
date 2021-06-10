#!/usr/bin/env bash

# Set Bash behaviour
set -o errexit      #Exit on uncaught errors
set -o pipefail 	#Fail pipe on first error

if [ $(whoami) != 'root' ];then
	printf "Run script with sudo or as root.\n"
	exit 1;
fi

add_user() {
    local user
    user="${1}"
    adduser --disabled-password --gecos "" "${user}"
    usermod -aG root "${user}"
    mkdir -m700 "/home/${user}/.ssh"
    chown -R "${user}:${user}" "/home/${user}/.ssh"
    touch "/home/${user}/.ssh/authorized_keys"
    chmod 600 "/home/${user}/.ssh/authorized_keys"
    chown -R "${user}:${user}" "/home/${user}/.ssh/"
    echo "${user} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
}

configure_zsh() {
    local user
    user="${1}"
    sudo -u "${user}" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    sudo -u "${user}" wget -O /home/robin/.zshrc https://raw.githubusercontent.com/stefanfluit/default_files/master/oh_my_zsh/.zshrc-pnd
    sed -i "s/empty-user/${user}/g" "/home/${user}/.zshrc"
    chsh -s $(which zsh) "${user}"
}

declare -a users=(
    "fluit"
    "robin"
)

declare -a keys=(
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC7N8v/BSL254L8Ph2CchKMGRNW0wpfh+6d1dR4o5plC stefan.fluit@fedora.robinradar.systems"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA/4jgVyo1ZNtfnF5DJh0k0wQOmg8oLowhHaFU/Vw7n1 stefan.fluit@robinradar.com"
)

declare -a programs=(
  "zsh"
  "apt-transport-https"
  "ca-certificates"
  "curl"
  "git"
  "software-properties-common"
  "python-is-python3"
  "fonts-powerline"
  "gnupg-agent"
  "vim"
  "mtr"
)

for user in "${users[@]}"; do
    add_user "${user}"
    configure_zsh "${user}"
done

for key in "${keys[@]}"; do
    for user in "${users[@]}"; do
        printf "%s\n" "${key}" >> "/home/${user}/.ssh/authorized_keys"
    done
done

for program in "${programs[@]}"; do
    apt-get -y install "${program}"
done

# Commands
# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
systemctl enable docker --now

# Download latest docker-compose
curl https://api.github.com/repos/docker/compose/releases/latest | grep browser_download_url | grep docker-compose-Linux-x86_64 | cut -d '"' -f 4 | wget -qi -
cp docker-compose-Linux-x86_64 /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Download latest Prometheus Node Exporter
curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep browser_download_url | grep linux-amd64 | cut -d '"' -f 4 | wget -qi -
tar xvf  $(find $(pwd) -name 'node_exporter*.tar.gz')
cp $(find $(pwd) -name 'node_exporter*' -type d)/node_exporter /usr/local/bin
curl -s https://gist.githubusercontent.com/stefanfluit/8d1c7fb1b2af8da487295ada4e64060c/raw/c870e1000b1b22f87cfb5f229bb878f4f786e07b/node_exporter.service >> /etc/systemd/system/node_exporter.service
groupadd --system node_exporter
useradd -s /sbin/nologin -r -g node_exporter node_exporter
systemctl daemon-reload
systemctl enable node_exporter --now