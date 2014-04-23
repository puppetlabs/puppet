test_name "ENC node information is used when store configs enabled (#16698)"

confine :except, :platform => 'solaris'
confine :except, :platform => 'windows'
confine :except, :platform => 'el-6'
confine :except, :platform => 'el-7'
confine :except, :platform => 'lucid'
confine :except, :platform => 'sles-11'

testdir = master.tmpdir('use_enc')

create_remote_file master, "#{testdir}/enc.rb", <<END
#!#{master['puppetbindir']}/ruby
require 'yaml'
puts({
       'classes' => [],
       'parameters' => {
         'data' => 'data from enc'
       },
     }.to_yaml)
END
on master, "chmod 755 #{testdir}/enc.rb"

create_remote_file(master, "#{testdir}/site.pp", 'notify { $data: }')

on master, "chown -R #{master['user']}:#{master['group']} #{testdir}"
on master, "chmod -R g+rwX #{testdir}"

create_remote_file master, "#{testdir}/setup.pp", <<END

$active_record_version = $osfamily ? {
  RedHat => $lsbmajdistrelease ? {
    5       => '2.2.3',
    default => '3.2.16',
  },
  default => '3.2.16',
}

# Trusty doesn't have a rubygems package anymore
# Not sure which other Debian's might follow suit so
# restricting this narrowly for now
#
if $lsbdistid == "Ubuntu" and $lsbdistrelease == "14.04" {
  package {
    activerecord:
      ensure => $active_record_version,
      provider => 'gem',
  }
} else {
  package {
    rubygems:
      ensure => present;

    activerecord:
      ensure => $active_record_version,
      provider => 'gem',
      require => Package[rubygems];
  }
}

if $osfamily == "Debian" {
  package {
    # This is the deb sqlite3 package
    sqlite3:
      ensure => present;

    libsqlite3-dev:
      ensure => present,
      require => Package[sqlite3];

  }
} elsif $osfamily == "RedHat" {
  $sqlite_gem_pkg_name = $operatingsystem ? {
    "Fedora" => "rubygem-sqlite3",
    default => "rubygem-sqlite3-ruby"
  }

  package {
    sqlite:
      ensure => present;

    $sqlite_gem_pkg_name:
      ensure => present,
      require => Package[sqlite]
  }
} else {
  fail "Unknown OS $osfamily"
}
END

# This is a brute force hack around PUP-1073 because the deb for the core
# sqlite3 package and the rubygem for the sqlite3 driver are both named
# 'sqlite3'.  So we just run a second puppet apply.
create_remote_file master, "#{testdir}/setup_sqlite_gem.pp", <<END
if $osfamily == "Debian" {
  package {
    # This is the rubygem sqlite3 driver
    sqlite3-gem:
      name => 'sqlite3',
      ensure => present,
      provider => 'gem',
  }
}
END

on master, puppet_apply("#{testdir}/setup.pp")
on master, puppet_apply("#{testdir}/setup_sqlite_gem.pp")

master_opts = {
  'master' => {
    'node_terminus' => 'exec',
    'external_nodes' => "#{testdir}/enc.rb",
    'storeconfigs' => true,
    'dbadapter' => 'sqlite3',
    'dblocation' => "#{testdir}/store_configs.sqlite3",
    'manifest' => "#{testdir}/site.pp"
  }
}

with_puppet_running_on master, master_opts, testdir do
  agents.each do |agent|
    run_agent_on(agent, "--no-daemonize --onetime --server #{master} --verbose")
    assert_match(/data from enc/, stdout)
  end
end
