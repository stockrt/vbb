#!/bin/bash

# Vagrant Base Box (vbb) setup steps for CentOS/RedHat/Fedora.
#
# Author: Rogério Schneider <stockrt@gmail.com>
# Date: 27/05/2015

puts () {
    # Pretty print.

    echo
    echo -e "\033[0;96m* $@\033[0;39m"
}

line () {
    # Insert line into file if not present.

    content="$1"
    file="$2"

    ! grep -q "$content" "$file" >/dev/null 2>&1 && \
        puts "Inserting \"$content\" into \"$file\"" && \
        echo "$content" >> "$file"
}

# Root.
valid_user="root"
current_user=$(id -u -n)
if [[ "$current_user" != "$valid_user" ]]
then
    echo "Invalid user \"$current_user\", you must run this script as $valid_user"
    exit 1
fi

# VirtualBox Guest Additions.
# Must first use VirtualBox shortcut "Host+D"
# or use menu "Devices / Insert Guest Additions CD Image..."
if [[ ! -f "/usr/bin/VBoxClient" ]]; then
    puts "Installing VirtualBox Guest Additions"
    if [[ ! -f "/media/VBoxLinuxAdditions.run" ]]; then
        echo 'Must first use VirtualBox shortcut "Host+D"'
        echo 'or use menu "Devices / Insert Guest Additions CD Image..."'
        exit 1
    fi
    /media/VBoxLinuxAdditions.run
fi

# Package.
yum install -y curl

# Vagrant user.
! getent passwd vagrant >/dev/null 2>&1 && \
    puts "Creating user: vagrant" && \
    useradd \
        -U \
        -m \
        -c Vagrant \
        -d /home/vagrant \
        -k /etc/skel \
        -s /bin/bash \
        vagrant

# Sudo.
line "vagrant ALL=(ALL) NOPASSWD: ALL" /etc/sudoers
sed -i 's/^\(Defaults.*requiretty\)/#\1/' /etc/sudoers

# SSH.
sed -i 's/^\(UseDNS.*yes\)/#\1/' /etc/ssh/sshd_config
line 'UseDNS no' /etc/ssh/sshd_config

# Passwords, generated with: openssl passwd -1 'vagrant'
passwords='
root:$1$Pynd3ikJ$YHAFHiJiM.Ac1i7Ac1xV31
vagrant:$1$Pynd3ikJ$YHAFHiJiM.Ac1i7Ac1xV31
'
for userpass in $passwords
do
    # Remove longest match of ":*" from back of string to extract the username.
    u="${userpass%%:*}" # username
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
su - vagrant -c "
mkdir -p ~/.ssh ;\
curl -sk https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant.pub -o ~/.ssh/authorized_keys ;\
chmod 0700 ~/.ssh ;\
chmod 0600 ~/.ssh/authorized_keys
"

# Clean history.
rm -f /home/vagrant/.bash_history
history -c
history -a
rm -f .bash_history
