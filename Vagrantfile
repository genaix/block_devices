# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'open3'
require 'fileutils'

def get_vm_name(id)
  out, err = Open3.capture2e('VBoxManage list vms')
  raise out unless err.exitstatus.zero?

  path = File.dirname(__FILE__).split('/').last
  name = out.split(/\n/)
            .select { |x| x.start_with? "\"#{path}_#{id}" }
            .map { |x| x.tr('"', '') }
            .map { |x| x.split(' ')[0].strip }
            .first
end


def controller_exists(name, controller_name)
  return false if name.nil?

  out, err = Open3.capture2e("VBoxManage showvminfo #{name}")
  raise out unless err.exitstatus.zero?

  out.split(/\n/)
     .select { |x| x.start_with? 'Storage Controller Name' }
     .map { |x| x.split(':')[1].strip }
     .any? { |x| x == controller_name }
end


# add NVME disks
def create_nvme_disks(vbox, name)
  controller_name = 'NVMe Controller'
  if not controller_exists(name, controller_name)
    vbox.customize ['storagectl', :id,
                    '--name', controller_name,
                    '--add', 'pcie']
  end

  dir = "./vdisks"
  FileUtils.mkdir_p dir unless File.directory?(dir)

  disks = (0..6).map { |x| ["nvmedisk#{x}", '512'] }

  disks.each_with_index do |(name, size), i|
    file_to_disk = "#{dir}/#{name}.vdi"
    port = (i).to_s

    unless File.exist?(file_to_disk)
      vbox.customize ['createmedium',
                      'disk',
                      '--filename',
                      file_to_disk,
                      '--size',
                      size,
                      '--format',
                      'VDI',
                      '--variant',
                      'standard']
    end

    vbox.customize ['storageattach', :id,
                    '--storagectl', controller_name,
                    '--port', port,
                    '--type', "hdd",
                    '--medium', file_to_disk]

  end
end


def create_disks(vbox, name, box)
   controller_name = 'SATA Controller'
   if not controller_exists(name, controller_name) and not box.include?('almalinux')
    vbox.customize ['storagectl', :id,
                    '--name', controller_name,
                    '--add', 'sata']
  end

  dir = "./vdisks"
  FileUtils.mkdir_p dir unless File.directory?(dir)

  disks = (1..8).map { |x| ["disk#{x}", '512'] }

  disks.each_with_index do |(name, size), i|
    file_to_disk = "#{dir}/#{name}.vdi"
    port = (i + 1).to_s

    unless File.exist?(file_to_disk)
      vbox.customize ['createmedium',
                      'disk',
                      '--filename',
                      file_to_disk,
                      '--size',
                      size,
                      '--format',
                      'VDI',
                      '--variant',
                      'standard']
    end

    vbox.customize ['storageattach', :id,
                    '--storagectl', controller_name,
                    '--port', port,
                    '--type', 'hdd',
                    '--medium', file_to_disk,
                    '--device', '0']

    vbox.customize ['setextradata', :id,
                    "VBoxInternal/Devices/ahci/0/Config/Port#{port}/SerialNumber",
                    name.ljust(20, '0')]
  end
end

Vagrant.configure("2") do |config|

  config.vm.define "server" do |server|
    #config.vm.box = 'centos/8'
    config.vm.box = 'almalinux/8'
    #config.vm.box_version = "2011.0"
    server.vm.host_name = 'server'
    server.vm.network :private_network, ip: "192.168.58.5"

    server.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      vb.customize ["modifyvm", :id, "--ioapic", "on"]
      vb.customize ["modifyvm", :id, "--chipset", "ich9"]
      name = get_vm_name('server')
      create_disks(vb, name, config.vm.box)
      create_nvme_disks(vb, name)
    end
  end

  config.vm.provision "shell", inline: <<-EOF
      sudo -i
      yum install -y gdisk mdadm
  EOF

  config.vm.provision "shell", inline: <<-EOF
      sgdisk -n 1:2048:+500M /dev/nvme0n1
      for i in {2..6} ; do sgdisk -R /dev/nvme0n${i} /dev/nvme0n1; done
      for i in {1..6} ; do sgdisk -G /dev/nvme0n${i}; done
      lsblk
      export DEVICE_NVME_LIST
      for i in {1..6} ; do export DEVICE_NVME_LIST="$DEVICE_NVME_LIST /dev/nvme0n${i}"; done
      mdadm --create /dev/md/raid10_nvme --run --level=10 --raid-devices=6 $DEVICE_NVME_LIST
      mdadm --detail /dev/md/raid10_nvme
      cat /proc/mdstat
      mkdir -p /etc/mdadm  # autoboot
      mdadm --detail --scan > /etc/mdadm/mdadm.conf
  EOF

end
