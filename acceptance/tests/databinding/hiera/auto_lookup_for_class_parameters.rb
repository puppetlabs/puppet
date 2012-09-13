confine :except, :platform => 'solaris'
begin test_name "Auto lookup for class parameters"

step "Setup"

apply_manifest_on master, <<-PP
file { '/etc/puppet/hieradata':
  ensure  => directory,
  recurse => true,
  purge   => true,
  force   => true,
}

file { '/etc/puppet/hiera.yaml':
  ensure  => present,
  content => '---
    :backends:
      - "puppet"
      - "yaml"
    :logger: "console"
    :hierarchy:
      - "%{fqdn}"
      - "%{environment}"
      - "global"

    :yaml:
      :datadir: "/etc/puppet/hieradata"
  '
}
PP

testdir = master.tmpdir('databinding')

create_remote_file(master, "#{testdir}/puppet.conf", <<END)
[main]
  manifest   = "#{testdir}/site.pp"
  modulepath = "#{testdir}/modules"
END

on master, "mkdir -p #{testdir}/modules/ssh/manifests"
on master, "mkdir -p #{testdir}/modules/ntp/manifests"

agent_names = agents.map { |agent| "'#{agent.to_s}'" }.join(', ')
create_remote_file(master, "#{testdir}/site.pp", <<-PP)
node default {
  include ssh::server
}
PP

create_remote_file(master, "#{testdir}/modules/ssh/manifests/init.pp", <<-PP)
class ssh::server($port, $usepam, $listenaddress) {
  notify { "port from hiera":
    message => "SSH server port: ${port}"
  }
  notify { "usepam from hiera":
    message => "SSH server UsePam: ${usepam}"
  }
  notify { "listenaddress from hiera":
    message => "SSH server ListenAddress: ${listenaddress}"
  }
}
PP

on master, "chown -R root:puppet #{testdir}"
on master, "chmod -R g+rwX #{testdir}"

step "Setup Hiera data"

apply_manifest_on master, <<-PP
file { '/etc/puppet/hieradata/global.yaml':
  ensure  => present,
  content => "---
    'ssh::server::port': 22
    'ssh::server::usepam': 'yes'
    'ssh::server::listenaddress': '0.0.0.0'
  "
}
PP

step "Should lookup class paramters from Hiera"

with_master_running_on(master, "--config #{testdir}/puppet.conf --debug --verbose --daemonize --dns_alt_names=\"puppet,$(facter hostname),$(facter fqdn)\" --autosign true") do
  agents.each do |agent|
    run_agent_on(agent, "--no-daemonize --onetime --verbose --server #{master}")

    assert_match("SSH server port: 22", stdout)
    assert_match("SSH server UsePam: yes", stdout)
    assert_match("SSH server ListenAddress: 0.0.0.0", stdout)
  end
end

ensure step "Teardown"
on master, "rm -rf #{testdir}"
apply_manifest_on master, <<-PP
file { '/etc/puppet/hieradata':
  ensure  => directory,
  recurse => true,
  purge   => true,
  force   => true,
}
file { '/etc/puppet/hiera.yaml':
  ensure => absent,
}
PP
end
