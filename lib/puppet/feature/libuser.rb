require 'puppet/util/feature'
require 'puppet/util/libuser'

Puppet.features.add(:libuser) {
   File.executable?("/usr/sbin/lgroupadd") &&
   File.executable?("/usr/sbin/luseradd")  &&
   Puppet::FileSystem.exist?(Puppet::Util::Libuser.getconf)
}
