test_name "ENC node information is used when store configs enabled (#16698)"
require 'puppet/acceptance/classifier_utils.rb'
extend Puppet::Acceptance::ClassifierUtils

confine :to, :platform => ['debian', 'ubuntu']
confine :except, :platform => 'lucid'

skip_test "Test not supported on jvm" if @options[:is_puppetserver]

testdir = master.tmpdir('use_enc')

apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
  File {
    ensure => directory,
    mode => "0770",
    owner => #{master.puppet['user']},
    group => #{master.puppet['group']},
  }
  file {
    '#{testdir}':;
    '#{testdir}/environments':;
    '#{testdir}/environments/production':;
    '#{testdir}/environments/production/manifests':;
    '#{testdir}/environments/production/manifests/site.pp':
      ensure => file,
      mode => "0640",
      content => 'notify { $data: }';
  }
MANIFEST

if master.is_pe?
  group = {
    'name' => 'Data',
    'description' => 'A group to test that data is passed from the enc',
    'variables' => { :data => 'data from enc' }
  }
  create_group_for_nodes(agents, group)
else

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

end

master_opts = {
  'main' => {
    'environmentpath' => "#{testdir}/environments",
  },
}
master_opts['master'] = {
  'node_terminus' => 'exec',
  'external_nodes' => "#{testdir}/enc.rb",
  'storeconfigs' => true,
  'dbadapter' => 'sqlite3',
  'dblocation' => "#{testdir}/store_configs.sqlite3",
} if !master.is_pe?

with_puppet_running_on master, master_opts, testdir do
  agents.each do |agent|
    run_agent_on(agent, "--no-daemonize --onetime --server #{master} --verbose")
    assert_match(/data from enc/, stdout)
  end
end
