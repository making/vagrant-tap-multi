# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  config.vm.box = "ubuntu/jammy64"
  config.vm.synced_folder "./share", "/share" , type: "virtualbox"

  (1..1).each do |n| # !! multi nfs is not supported yet !!
    config.vm.define "nfs-#{n}" do |c|
      c.vm.hostname = "nfs-#{n}.internal"
      c.vm.network "private_network", ip: "192.168.56.5#{n}"
      # c.vm.network "public_network", ip: "192.168.11.5#{n}", bridge: "eno1: Ethernet"
      c.vm.provider "virtualbox" do |v|
        v.gui = false
        v.cpus = 1
        v.memory = 1024
      end

      c.vm.provision :shell, :path => "scripts/setup-initial-ubuntu.sh"
      c.vm.provision :shell, :path => "scripts/setup-nfs.sh"
      c.vm.provision :hosts, :sync_hosts => true
    end
  end

  (1..1).each do |n| # !! multi controlplane is not supported yet !!
    config.vm.define "controlplane-#{n}" do |c|
      c.vm.hostname = "controlplane-#{n}.internal"
      c.vm.network "private_network", ip: "192.168.56.6#{n}"
      # c.vm.network "public_network", ip: "192.168.11.6#{n}", bridge: "eno1: Ethernet"
      c.vm.provider "virtualbox" do |v|
        v.gui = false
        v.cpus = 2
        v.memory = 4096
      end

      c.vm.provision :shell, :path => "scripts/setup-initial-ubuntu.sh"
      c.vm.provision :shell, :path => "scripts/setup-microk8s.sh"
      c.vm.provision :shell, :path => "scripts/setup-microk8s-controlplane.sh"
      c.vm.provision :hosts, :sync_hosts => true
    end
  end

  (1..3).each do |n|
    config.vm.define "worker-#{n}" do |c|
      c.vm.hostname = "worker-#{n}.internal"
      c.vm.network "private_network", ip: "192.168.56.7#{n}"
      # c.vm.network "public_network", ip: "192.168.11.7#{n}", bridge: "eno1: Ethernet"
      c.vm.provider "virtualbox" do |v|
        v.gui = false
        v.cpus = 2
        v.memory = 4096
      end

      c.vm.provision :shell, :path => "scripts/setup-initial-ubuntu.sh"
      c.vm.provision :shell, :path => "scripts/setup-microk8s.sh"
      c.vm.provision :shell, :path => "scripts/setup-microk8s-worker.sh"
      c.vm.provision :hosts, :sync_hosts => true      
    end
  end  
end