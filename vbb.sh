#!/bin/bash

# Vagrant Base Box (vbb) setup steps for CentOS/RedHat/Fedora.
#
# Author: Rogério Schneider <stockrt@gmail.com>
# Created: May 27, 2015

# Pretty print.
puts () {
    echo
    echo -e "\033[0;96m* $@\033[0;39m"
}

# Insert line into file if not present.
line () {
    content="$1"
    file="$2"
    extra_options="$3"

    ! grep -q $extra_options "$content" "$file" >/dev/null 2>&1 && \
        puts "Inserting \"$content\" into \"$file\"" && \
        echo "$content" >> "$file"
}

# Root.
valid_user='root'
current_user=$(id -u -n)
if [[ "$current_user" != "$valid_user" ]]
then
    echo "Invalid user \"$current_user\", you must run this script as $valid_user"
    exit 1
fi

# Routes.
if [[ -f /etc/sysconfig/network-scripts/route-* ]]; then
    rm -f /etc/sysconfig/network-scripts/route-*
    service network restart
fi

# VirtualBox Guest Additions.
# Must first use VirtualBox shortcut "Host+D"
# or use menu "Devices / Insert Guest Additions CD Image..."
if [[ ! -f '/usr/bin/VBoxClient' ]]; then
    puts 'Installing VirtualBox Guest Additions'
    umount /media
    mount /dev/cdrom /media
    if [[ ! -f '/media/VBoxLinuxAdditions.run' ]]; then
        echo 'Must first use VirtualBox shortcut "Host+D"'
        echo 'or use menu "Devices / Insert Guest Additions CD Image..."'
        exit 1
    fi
    /media/VBoxLinuxAdditions.run
fi

# Package.
yum install -y curl wget

# Vagrant user.
! getent passwd vagrant >/dev/null 2>&1 && \
    puts 'Creating user: vagrant' && \
    useradd \
        -U \
        -m \
        -c Vagrant \
        -d /home/vagrant \
        -k /etc/skel \
        -s /bin/bash \
        vagrant

# Sudo.
sed -i 's/^\(Defaults.*requiretty\)/#\1/' /etc/sudoers
line 'vagrant ALL=(ALL) NOPASSWD: ALL' /etc/sudoers

# SSH.
sed -i 's/^\(UseDNS.*yes\)/#\1/' /etc/ssh/sshd_config
line 'UseDNS no' /etc/ssh/sshd_config
line 'sshd: 10.' /etc/hosts.allow -w

# Passwords, generated with: openssl passwd -1 'vagrant'
passwords='
root:$1$Pynd3ikJ$YHAFHiJiM.Ac1i7Ac1xV31
vagrant:$1$Pynd3ikJ$YHAFHiJiM.Ac1i7Ac1xV31
'
for userpass in $passwords
do
    # Remove longest match of ':*' from back of string to extract the username.
    u=${userpass%%:*} # username
    p=$(echo $userpass | cut -d: -f1,2) # password

    # Skip nonexistent users.
    getent passwd "$u" >/dev/null 2>&1 || continue

    # Change password.
    if [[ "$userpass" != $(getent shadow $u | cut -d: -f1,2) ]]
    then
        puts "Ensuring password for user: $u"
        chpasswd -e <<< "$userpass"
    fi
done

# Credentials.
su - vagrant -c '
mkdir -p ~/.ssh ;\
curl -sk https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant.pub -o ~/.ssh/authorized_keys ;\
chmod 0700 ~/.ssh ;\
chmod 0600 ~/.ssh/authorized_keys
'

# Fstab timeout and noauto.
sed -i 's/timeo=.*/timeo=14,noauto 0 0/g' /etc/fstab

# Clean history.
rm -f /home/vagrant/.bash_history
rm -f .bash_history
puts "Clean history for \"$current_user\" and turn the machine off running the command bellow:"
echo
echo 'export HISTFILE=/dev/null && halt'
echo
