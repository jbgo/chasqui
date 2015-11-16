# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = 'hashicorp/precise64'

  config.vm.network 'forwarded_port', guest: 6379, host: 6379

  config.vm.provision "shell", inline: <<-SHELL
    sudo apt-get update
    sudo apt-get install -y redis-server
    sudo sed -ie 's/bind 127.0.0.1/bind 0.0.0.0/' /etc/redis/redis.conf
    sudo service redis-server restart
  SHELL
end
