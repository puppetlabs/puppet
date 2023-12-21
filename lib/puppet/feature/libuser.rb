# frozen_string_literal: true

require_relative '../../puppet/util/feature'
require_relative '../../puppet/util/libuser'

Puppet.features.add(:libuser) {
  File.executable?("/usr/sbin/lgroupadd") and
    File.executable?("/usr/sbin/luseradd") and
    Puppet::FileSystem.exist?(Puppet::Util::Libuser.getconf)
}
