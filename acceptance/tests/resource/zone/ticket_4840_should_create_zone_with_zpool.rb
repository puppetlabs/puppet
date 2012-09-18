test_name "Zone: ticket #4840 - verify that the given manifest works."
confine :to, :platform => 'solaris:pending'

require 'puppet/acceptance/solaris_util'
extend Puppet::Acceptance::ZoneUtils

teardown do
  agents.each do |agent|
    clean agent
  end
end

agents.each do |agent|
  setup agent
  #-----------------------------------
  # Make sure that the zone is absent.
  apply_manifest_on(agent,%[
    zfs { "tstpool/tstfs":
      mountpoint => "/ztstpool/mnt",
      ensure => present,
    }
    file { "/ztstpool/mnt":
      ensure => directory,
      mode => 0700,
      require => Zfs["tstpool/tstfs"],
    }
    zone { tstzone:
      autoboot => true,
      path => "/ztstpool/mnt",
      sysidcfg => "/tmp/myzone.cfg",
      iptype => exclusive,
      ip => "ip.if.1",
      require => File["/ztstpool/mnt"],
    }]) do
    assert_match( /ensure: created/, result.stdout, "err: #{agent}")
  end
end
