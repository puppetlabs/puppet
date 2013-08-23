confine :except, :platform => 'solaris'
begin test_name "Auto lookup for class parameters"

testdir = master.tmpdir('databinding')

step "Setup"

apply_manifest_on master, <<-PP
file { '#{testdir}/hieradata':
  ensure  => directory,
  recurse => true,
  purge   => true,
  force   => true,
}

file { '#{testdir}/hiera.yaml':
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
      :datadir: "#{testdir}/hieradata"
  '
}
PP


on master, "if [ -f #{master['puppetpath']}/hiera.yaml ]; then cp #{master['puppetpath']}/hiera.yaml #{master['puppetpath']}/hiera.yaml.bak; fi"
on master, "cat #{testdir}/hiera.yaml > #{master['puppetpath']}/hiera.yaml"
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

on master, "chown -R #{master['user']}:#{master['group']} #{testdir}"
on master, "chmod -R g+rwX #{testdir}"

step "Setup Hiera data"

apply_manifest_on master, <<-PP
file { '#{testdir}/hieradata/global.yaml':
  ensure  => present,
  content => "---
    'ssh::server::port': 22
    'ssh::server::usepam': 'yes'
    'ssh::server::listenaddress': '0.0.0.0'
  "
}
PP

step "Should lookup class paramters from Hiera"

master_opts = {
  'master' => {
    'manifest' => "#{testdir}/site.pp",
    'modulepath' => "#{testdir}/modules",
    'node_terminus'   => 'plain',
  }
}

with_puppet_running_on master, master_opts, testdir do
  agents.each do |agent|
    on(agent, puppet('agent', "-t --server #{master}"), :acceptable_exit_codes => [0,2]) do |res|

      assert_match("SSH server port: 22", res.stdout)
      assert_match("SSH server UsePam: yes", res.stdout)
      assert_match("SSH server ListenAddress: 0.0.0.0", res.stdout)
    end
  end
end

ensure step "Teardown"
  on master, "if [ -f #{master['puppetpath']}/hiera.yaml.bak ]; then " +
               "cat #{master['puppetpath']}/hiera.yaml.bak > #{master['puppetpath']}/hiera.yaml; " +
               "rm -rf #{master['puppetpath']}/hiera.yaml.bak; " +
             "fi"
end
