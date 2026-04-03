#!/bin/bash

# saves the key to the proper location
ssh-keygen -t id_ed25519.pub -f /home/deployer/.ssh/id_ed25519

# fix all the permissions
user='deployer'
chmod 700 ./.ssh
chmod 600 ./authorized_keys
sudo chown -R $user:$user /home/$user/.ssh
