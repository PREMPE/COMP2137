#!/bin/bash
# script block used to conveniently capture all output from script
{
export PAGER=more
checkscript=https://github.com/zonzorp/COMP2137/raw/main/check-assign2-script.sh
makecontainers=https://github.com/zonzorp/COMP2137/raw/main/makecontainers.sh

function userimpatient {
echo "please let the script finish"
sleep 2
}
trap userimpatient SIGINT

echo ---Host/Student info----
echo "
Running on $(date)
Run by $USER - ($id) on host
$(hostnamectl|egrep 'hostname|Machine|Operating')
$(md5sum $0) - $(wget -q -O - $checkscript|md5sum)"
echo ------------------------
echo

echo ---Start of Assignment2.sh Check------
if [ ! -f ~/makecontainers.sh ]; then
	if wget -O ~/makecontainers.sh "$makecontainers" ; then
		echo "Retrieved makecontainers.sh script"
                chmod +x ~/makecontainers.sh
	else
		echo "Failed to retrieve makecontainers.sh script"
		exit 1
	fi
else
	if [ ! -x ~/makecontainers.sh ]; then
		chmod +x ~/makecontainers.sh || exit 1
	fi
fi

echo ---Running makecontainers.sh----------
~/makecontainers.sh --count 1 --target server --fresh || exit 1
sleep 30

# make ssh keys
ssh-keygen -f ~/.ssh/known_hosts -R server1-mgmt

echo ---Retrieving assignment2.sh script---
if wget -q -O assignment2.sh "$1"; then
	echo "Retrieved assignment2 script"
	chmod +x assignment2.sh
	if scp -o StrictHostKeyChecking=off assignment2.sh remoteadmin@server1-mgmt: ; then
		echo "Copied assignment2.sh script to server1"
	else
		echo "Failed to copy assignment2.sh to server1"
		exit 1
	fi
else
	echo "Failed to retrieve assignment2.sh script using URL '$1'"
	exit 1
fi

echo ---assignment2.sh run----
ssh -o StrictHostKeyChecking=off remoteadmin@server1-mgmt /home/remoteadmin/assignment2.sh || exit 1
echo -------------------------
echo

echo --network--------
incus exec server1 sh -- -c 'for f in /etc/hosts /etc/netplan/*; do printf "$f\n-----------------------\n"; cat $f; echo "-------------"; done'
echo ---applying netplan---
incus exec server1 sh -- -c 'netplan apply'
echo ---ip a---------------
incus exec server1 sh -- -c 'ip a'
echo --ip r----------------
incus exec server1 sh -- -c 'ip r'
echo ----------------------
echo

echo ---services status------
incus exec server1 -- sh -c 'systemctl status apache2 squid'
echo ------------------------
echo

echo ---ufw show added-------
incus exec server1 ufw show added
echo ---ufw show status------
incus exec server1 ufw status
echo ------------------------
echo

echo ---getents--------------------
incus exec server1 getent passwd {aubrey,captain,snibbles,brownie,scooter,sandy,perrier,cindy,tiger,yoda,dennis}
incus exec server1 getent group sudo
echo ---user home dir contents-----
incus exec server1 -- find /home -type f -ls
incus exec server1 sh -- -c 'for f in /home/*/.ssh/authorized_keys; do printf "$f\n-----------------------\n"; cat $f; echo "-------------"; done'
echo ------------------------------
echo

echo ---assignment2.sh rerun--------------------------------------------------------------------
ssh -o StrictHostKeyChecking=off remoteadmin@server1-mgmt /home/remoteadmin/assignment2.sh || exit 1
echo -------------------------------------------------------------------------------------------
echo

echo --network--------
incus exec server1 sh -- -c 'for f in /etc/hosts /etc/netplan/*; do printf "$f\n-----------------------\n"; cat $f; echo "-------------"; done'
echo ---applying netplan---
incus exec server1 sh -- -c 'netplan apply'
echo ---ip a---------------
incus exec server1 sh -- -c 'ip a'
echo --ip r----------------
incus exec server1 sh -- -c 'ip r'
echo ----------------------
echo

echo ---services status------
incus exec server1 -- sh -c 'systemctl status apache2 squid'
echo ------------------------
echo

echo ---getents--------------------
incus exec server1 getent passwd {aubrey,captain,snibbles,brownie,scooter,sandy,perrier,cindy,tiger,yoda,dennis}
incus exec server1 getent group sudo
echo ---user home dir contents-----
incus exec server1 -- find /home -type f -ls
incus exec server1 sh -- -c 'for f in /home/*/.ssh/authorized_keys; do printf "$f\n-----------------------\n"; cat $f; echo "-------------"; done'
echo ------------------------------
echo

} >check-assign2-output.txt 2>check-assign2-errors.txt
#!/bin/bash

# starting message
echo "Starting Assignment 2 setup..."

# STEP 1 – Configure static IP for eth0 using Netplan (safely)
file="/etc/netplan/01-netcfg.yaml"

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
echo "Netplan applied with static IP and clean routes"

# STEP 2 – Update /etc/hosts entry
echo "Updating /etc/hosts..."
sed -i '/server1/d' /etc/hosts
echo "192.168.16.21 server1" >> /etc/hosts
echo "/etc/hosts updated"

# STEP 3 – Install required software
echo "Installing apache2 and squid..."
apt update
apt install apache2 -y
apt install squid -y
systemctl enable apache2
systemctl enable squid
systemctl start apache2
systemctl start squid
echo "apache2 and squid are running"

# STEP 4 – Create users and set up SSH keys
users="dennis aubrey captain snibbles brownie scooter sandy perrier cindy tiger yoda"

for user in $users
do
    # check if user exists
    id $user > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        useradd -m -s /bin/bash "$user"
        echo "Created user: $user"
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
        echo "Added sudo access and professor's key to dennis"
    fi

    # fix permissions
    chown -R $user:$user /home/$user/.ssh
    chmod 700 /home/$user/.ssh
    chmod 600 /home/$user/.ssh/authorized_keys
done

# done message
echo "Assignment 2 setup complete. You can re-run this script safely anytime!"

