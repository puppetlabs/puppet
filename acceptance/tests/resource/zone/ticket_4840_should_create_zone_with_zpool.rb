test_name "Zone: ticket #4840 - verify that the given manifest works."
confine :to, :platform => 'solaris:pending'
# If you plan to enable it, it would be a good idea to have a multi-cpu system with
# atleast 2G ram. If it takes too long, open agent and try
# truss -t open -p <auto-install:pid>
# The auto install pid can be found by using ptree on the puppet apply pid
# (use grep)

require 'puppet/acceptance/solaris_util'
extend Puppet::Acceptance::ZoneUtils

teardown do
  agents.each do |agent|
    clean agent
  end
end

agents.each do |agent|
  clean agent
  setup agent, :size => '1536m'
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
      path => '/ztstpool/mnt',
      sysidcfg => '/tmp/myzone.cfg',
      iptype => exclusive,
      require => File["/ztstpool/mnt"],
      ip => vnic3,
    }]) do
    assert_match( /ensure: created/, result.stdout, "err: #{agent}")
  end
end
