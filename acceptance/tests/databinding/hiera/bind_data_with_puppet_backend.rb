begin test_name "Lookup data using the hiera parser function"

step 'Setup'
testdir = master.tmpdir('hiera')

on master, "if [ -f #{master['puppetpath']}/hiera.yaml ]; then cp #{master['puppetpath']}/hiera.yaml #{master['puppetpath']}/hiera.yaml.bak; fi"

on master, "mkdir -p #{testdir}/modules/apache/manifests"
on master, "mkdir -p #{testdir}/hieradata"

apply_manifest_on master, <<-PP
file { '#{testdir}/hieradata/global.yaml':
  ensure  => present,
  content => "---
    apache::port: 8080
  "
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

agent_names = agents.map { |agent| "'#{agent.to_s}'" }.join(', ')
create_remote_file(master, "#{testdir}/site.pp", <<-PP)
node default {
  include apache
}
PP

create_remote_file(master, "#{testdir}/modules/apache/manifests/init.pp", <<-PP)
class apache($port) {
  notify { "port from hiera":
    message => "apache server port: ${port}"
  }
}
PP

on master, "chown -R #{master['user']}:#{master['group']} #{testdir}"
on master, "chmod -R g+rwX #{testdir}"
on master, "cat #{testdir}/hiera.yaml > #{master['puppetpath']}/hiera.yaml"


step "Try to lookup string data"

master_opts = {
  'master' => {
    'data_binding_terminus' => 'hiera',
    'manifest' => "#{testdir}/site.pp",
    'modulepath' => "#{testdir}/modules",
    'node_terminus' => nil
  }
}

with_puppet_running_on master, master_opts, testdir do
  agents.each do |agent|
    on(agent, puppet('agent', "--no-daemonize --onetime --verbose --server #{master}"))

    assert_match("apache server port: 8080", stdout)
  end
end

ensure step "Teardown"

on master, "if [ -f #{master['puppetpath']}/hiera.yaml.bak ]; then " +
             "cat #{master['puppetpath']}/hiera.yaml.bak #{master['puppetpath']}/hiera.yaml; " +
             "rm -rf #{master['puppetpath']}/hiera.yaml.bak; " +
           "fi"

end
