#!/bin/bash

# You MUST edit for YOUR environment. User, port, etc.
# Tested on Ubuntu 22, haven't tested these latest changes yet on Ubuntu 20.

# Change root pw and exit
echo "Change root password?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) passwd; break;;
        No ) break;;
    esac
done

if [[ $yn = "Yes" ]]
then
  echo "exit the terminal, log back in as root and test the new password."
  exit
else
  # Works on Ubuntu 22, might throw error on Ubuntu 20 (haven't tested yet)
  sed -i "/#\$nrconf{restart} = 'i';/s/.*/\$nrconf{restart} = 'a';/" /etc/needrestart/needrestart.conf
  sed -i "s/#\$nrconf{kernelhints} = -1;/\$nrconf{kernelhints} = -1;/g" /etc/needrestart/needrestart.conf

  adduser --gecos "" jojo # Update with YOUR user in every line of 'jojo'
  adduser jojo sudo
  
  mkdir /home/jojo/.ssh && chmod 700 /home/jojo/.ssh
  # Example of a public key used to log in, replace with your real public key
  echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBML8D3F9usKzTc6Q/bGzayGj2SUIw0GQOkd6lhD1No5 ed25519-key-20230315" > /home/jojo/.ssh/authorized_keys
  chmod 600 /home/jojo/.ssh/authorized_keys
  chown -R jojo:jojo /home/jojo/

  ufw allow 32145/tcp # Whatever your custom SSH port is, modify as needed
  yes | ufw enable
  systemctl restart ssh

  echo "What is the hostname?"
  read hostname
  hostnamectl set-hostname $hostname

  apt-get update
  apt-get install vim screen curl git fail2ban ufw htop -y

  sed -i '/^" let g:skip_defaults_vim = 1$/s/^" //' /etc/vim/vimrc
  vim1=$(grep 'let g:skip_defaults_vim = 1' /etc/vim/vimrc)
  echo "$vim1"

  sed -i 's/^"\(set background=dark\)/\1/' /etc/vim/vimrc
  vim2=$(grep 'set background=dark' /etc/vim/vimrc)
  echo "$vim2"

  sed -i 's/^"\(set mouse=a\).*$/set mouse=/' /etc/vim/vimrc
  vim3=$(grep 'set mouse=' /etc/vim/vimrc)
  echo "$vim3"

  apt-get update
  apt-get upgrade -y
  apt-get dist-upgrade -y
  apt-get autoremove -y

  timedatectl set-timezone America/Los_Angeles # Modify for your timezone

  cp -p /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
  sed -i '/^backend = %(sshd_backend)s$/a enabled = true\nfilter = sshd\nbanaction = iptables-multiport\nfindtime = 86400\nbantime = -1\nmaxretry = 3' /etc/fail2ban/jail.local

  systemctl restart fail2ban

  if swapon --show | grep -q "^/"; then
    echo "Swap file already exists"
  else
    fallocate -l 4G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
  fi

  echo 'vm.swappiness=5' | tee -a /etc/sysctl.conf
  echo 'vm.vfs_cache_pressure=50' | tee -a /etc/sysctl.conf
  
  sed -i 's/^#Port 22$/Port 32145/' /etc/ssh/sshd_config
  sed -i '/^Port 49222$/a AllowUsers jojo' /etc/ssh/sshd_config
  sed -i '/^#PasswordAuthentication\|^PasswordAuthentication/s/.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  sed -i '/^#PermitRootLogin\|^PermitRootLogin/s/.*/PermitRootLogin no/' /etc/ssh/sshd_config

  echo "exit the terminal and log in as user on ssh port 32145"
  exit
fi
