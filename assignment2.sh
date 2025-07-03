#!/bin/bash

# starting message
echo "Starting Assignment 2 setup..."

# STEP 1 – Configure static IP for eth0 using Netplan (safely)
file="/etc/netplan/01-network-manager-all.yaml"

# make sure file has secure permissions
chmod 600 "$file"

# set static IP using modern routing format (fix gateway4 warning)
echo "Updating Netplan config..."

echo "network:
  version: 2
  ethernets:
    eth0:
      dhcp4: no
      addresses: [192.168.16.21/24]
      routes:
        - to: 0.0.0.0/0
          via: 192.168.16.2
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]" > "$file"

# re-secure file after edit
chmod 600 "$file"

# validate and apply Netplan changes
netplan generate
netplan apply
echo " Netplan applied with static IP and clean routes"

# STEP 2 – Update /etc/hosts entry
echo "Updating /etc/hosts..."
sed -i '/server1/d' /etc/hosts
echo "192.168.16.21 server1" >> /etc/hosts
echo " /etc/hosts updated"

# STEP 3 – Install required software
echo "Installing apache2 and squid..."
apt update
apt install apache2 -y
apt install squid -y
systemctl enable apache2
systemctl enable squid
systemctl start apache2
systemctl start squid
echo " apache2 and squid are running"

# STEP 4 – Create users and set up SSH keys
users="dennis aubrey captain snibbles brownie scooter sandy perrier cindy tiger yoda"

for user in $users
do
    # check if user exists
    id $user > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        useradd -m -s /bin/bash "$user"
        echo " Created user: $user"
    fi

    # create .ssh folder
    mkdir -p /home/$user/.ssh

    # generate ssh keys if missing
    if [ ! -f /home/$user/.ssh/id_rsa ]; then
        ssh-keygen -t rsa -f /home/$user/.ssh/id_rsa -N "" > /dev/null
    fi
    if [ ! -f /home/$user/.ssh/id_ed25519 ]; then
        ssh-keygen -t ed25519 -f /home/$user/.ssh/id_ed25519 -N "" > /dev/null
    fi

    # setup authorized_keys
    cat /home/$user/.ssh/id_rsa.pub > /home/$user/.ssh/authorized_keys
    cat /home/$user/.ssh/id_ed25519.pub >> /home/$user/.ssh/authorized_keys

    # special setup for dennis
    if [ "$user" = "dennis" ]; then
        usermod -aG sudo dennis
        echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm" >> /home/$user/.ssh/authorized_keys
        echo " Added sudo access and professor's key to dennis"
    fi

    # fix permissions
    chown -R $user:$user /home/$user/.ssh
    chmod 700 /home/$user/.ssh
    chmod 600 /home/$user/.ssh/authorized_keys
done

# done message
echo " Assignment 2 setup complete. You can re-run this script safely anytime!"
