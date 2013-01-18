require 'puppet/util/feature'

Puppet.features.add(:libuser) { File.executable?("/usr/sbin/lgroupadd") and File.executable?("/usr/sbin/luseradd") }
