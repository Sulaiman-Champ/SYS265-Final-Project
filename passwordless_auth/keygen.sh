#!/bin/bash

user='deployer'

ssh-keygen -t id_ -C "ARBITRATRY"

chmod 700 ./.ssh
chmod 600 ./authorized_keys
sudo chown -R $user:$user /home/$user/.ssh
