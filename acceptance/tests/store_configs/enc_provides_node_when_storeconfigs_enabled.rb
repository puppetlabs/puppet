test_name "ENC node information is used when store configs enabled (#16698)"

confine :except, :platform => 'solaris'
confine :except, :platform => 'windows'
confine :except, :platform => 'el-6'

testdir = master.tmpdir('use_enc')

create_remote_file master, "#{testdir}/enc.rb", <<END
#!/usr/bin/env ruby
puts <<YAML
parameters:
  data: "data from enc"
YAML
END
on master, "chmod 755 #{testdir}/enc.rb"

create_remote_file master, "#{testdir}/puppet.conf", <<END
[main]
node_terminus = exec
external_nodes = "#{testdir}/enc.rb"
storeconfigs = true
dbadapter = sqlite3
dblocation = #{testdir}/store_configs.sqlite3
manifest = "#{testdir}/site.pp"
END

create_remote_file(master, "#{testdir}/site.pp", 'notify { $data: }')

on master, "chown -R root:puppet #{testdir}"
on master, "chmod -R g+rwX #{testdir}"

create_remote_file master, "#{testdir}/setup.pp", <<END
package {
  rubygems:
    ensure => present;

  activerecord:
    ensure => '2.2.3',
    provider => 'gem',
    require => Package[rubygems]
}

if $osfamily == "Debian" {
  package {
    sqlite3:
      ensure => present;

    libsqlite3-ruby:
      ensure => present,
      require => Package[sqlite3]
  }
} elsif $osfamily == "Redhat" {
  package {
    sqlite:
      ensure => present;

    rubygem-sqlite3-ruby:
      ensure => present,
      require => Package[sqlite]
  }
} else {
  fail "Unknown OS $osfamily"
}
END

on master, puppet_apply("#{testdir}/setup.pp")

with_master_running_on(master, "--config #{testdir}/puppet.conf --daemonize --dns_alt_names=\"puppet,$(facter hostname),$(facter fqdn)\" --autosign true") do
  agents.each do |agent|
    run_agent_on(agent, "--no-daemonize --onetime --server #{master} --verbose")
    assert_match(/data from enc/, stdout)
  end
end

on master, "rm -rf #{testdir}"
