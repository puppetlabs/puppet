require 'puppet/util/feature'
require 'puppet/util/libuser'

Puppet.features.add(:libuser) {
   File.executable?("/usr/sbin/lgroupadd") and
   File.executable?("/usr/sbin/luseradd")  and
   File.exists?(Puppet::Util::Libuser.getconf)
}
