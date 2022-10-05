# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  config.vm.box = "ubuntu/jammy64"
  config.vm.synced_folder "./share", "/share" , type: "virtualbox"

  config.vm.define "nfs" do |c|
    c.vm.hostname = "nfs.internal"
    c.vm.network "public_network", ip: "192.168.11.50", bridge: "eno1"
    c.vm.network "private_network", ip: "192.168.56.50"
    c.vm.provider "virtualbox" do |v|
      v.gui = false
      v.cpus = 1
      v.memory = 1024
    end
    c.disksize.size = '500GB'

    c.vm.provision :shell, :path => "scripts/setup-initial-ubuntu.sh"
    c.vm.provision :shell, :path => "scripts/setup-nfs.sh"
    c.vm.provision :hosts, :sync_hosts => true
  end

  config.vm.define "tap-view" do |c|
    c.vm.hostname = "tap-view.internal"
    c.vm.network "public_network", ip: "192.168.11.60", bridge: "eno1"
    c.vm.network "private_network", ip: "192.168.56.60"
    c.vm.provider "virtualbox" do |v|
      v.gui = false
      v.cpus = 4
      v.memory = 10240
    end
    c.disksize.size = '60GB'
    c.vm.provision :shell, :path => "scripts/setup-initial-ubuntu.sh"
    c.vm.provision :shell, :path => "scripts/setup-microk8s.sh"
    c.vm.provision :shell, :path => "scripts/setup-microk8s-controlplane.sh", :args => ["controlplane-1"]
    c.vm.provision :hosts, :sync_hosts => true
  end

  config.vm.define "tap-build" do |c|
    c.vm.hostname = "tap-build.internal"
    c.vm.network "public_network", ip: "192.168.11.61", bridge: "eno1"
    c.vm.network "private_network", ip: "192.168.56.61"
    c.vm.provider "virtualbox" do |v|
      v.gui = false
      v.cpus = 4
      v.memory = 15360
    end
    c.disksize.size = '70GB'
    c.vm.provision :shell, :path => "scripts/setup-initial-ubuntu.sh"
    c.vm.provision :shell, :path => "scripts/setup-microk8s.sh"
    c.vm.provision :shell, :path => "scripts/setup-microk8s-controlplane.sh", :args => ["controlplane-2"]
    c.vm.provision :hosts, :sync_hosts => true
  end

  config.vm.define "tap-run" do |c|
    c.vm.hostname = "tap-run.internal"
    c.vm.network "public_network", ip: "192.168.11.62", bridge: "eno1"
    c.vm.network "private_network", ip: "192.168.56.62"
    c.vm.provider "virtualbox" do |v|
      v.gui = false
      v.cpus = 7
      v.memory = 35840
    end
    c.disksize.size = '70GB'
    c.vm.provision :shell, :path => "scripts/setup-initial-ubuntu.sh"
    c.vm.provision :shell, :path => "scripts/setup-microk8s.sh"
    c.vm.provision :shell, :path => "scripts/setup-microk8s-controlplane.sh", :args => ["controlplane-3"]
    c.vm.provision :hosts, :sync_hosts => true
  end
  
end