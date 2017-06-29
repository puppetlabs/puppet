test_name "Zone: ticket #4840 - verify that the given manifest works."
confine :to, :platform => 'solaris'

tag 'audit:medium',
    'audit:refactor',  # Use block style `test_name`
    'audit:acceptance' # Could be done as integration tests, but would
                       # require drastically changing the system running the test

require 'puppet/acceptance/solaris_util'
extend Puppet::Acceptance::ZoneUtils

def poolsetup(agent)
  on agent,"mkdir /tstzones"
  on agent,"mkfile 2500m /tstzones/dsk"
  on agent,"zpool create tstpool /tstzones/dsk"
end

def poolclean(agent)
  on agent,"zfs destroy -r tstpool", :acceptable_exit_codes => [0,1]
  on agent,"zpool destroy tstpool", :acceptable_exit_codes => [0,1]
  on agent,"rm -rf /ztstpool", :acceptable_exit_codes => [0,1]
end

teardown do
  agents.each do |agent|
    clean agent
    poolclean agent
  end
end

agents.each do |agent|
  setup agent
  poolsetup agent
  #-----------------------------------
  # Make sure that the zone is absent.
  apply_manifest_on(agent,%[
    zfs { "tstpool/tstfs":
      mountpoint => "/ztstpool/mnt",
      ensure => present,
    }
    file { "/ztstpool/mnt":
      ensure => directory,
      mode => "0700",
      require => Zfs["tstpool/tstfs"],
    }
    zone { tstzone:
      autoboot => true,
      path => "/ztstpool/mnt",
      sysidcfg => "/tmp/myzone.cfg",
      iptype => exclusive,
      ip => net1,
      require => File["/ztstpool/mnt"],
    }]) do
    assert_match( /ensure: created/, result.stdout, "err: #{agent}")
  end
end
