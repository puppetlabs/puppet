require 'puppet/util/feature'
require 'puppet/util/libuser'

Puppet.features.add(:libuser) {
   File.executable?("/usr/sbin/lgroupadd") and
   File.executable?("/usr/sbin/luseradd")  and
   Puppet::FileSystem.exist?(Puppet::Util::Libuser.getconf)
}
