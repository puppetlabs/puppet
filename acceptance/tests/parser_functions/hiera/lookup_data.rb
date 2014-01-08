begin test_name "Lookup data using the hiera parser function"

testdir = master.tmpdir('hiera')

step 'Setup'
on master, "mkdir -p #{testdir}/hieradata"
on master, "if [ -f #{master['puppetpath']}/hiera.yaml ]; then cp #{master['puppetpath']}/hiera.yaml #{master['puppetpath']}/hiera.yaml.bak; fi"

apply_manifest_on master, <<-PP
file { '#{master['puppetpath']}/hiera.yaml':
  ensure  => present,
  content => '---
    :backends:
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

apply_manifest_on master, <<-PP
file { '#{testdir}/hieradata/global.yaml':
  ensure  => present,
  content => "---
    port: 8080
  "
}
PP

on master, "mkdir -p #{testdir}/modules/apache/manifests"

agent_names = agents.map { |agent| "'#{agent.to_s}'" }.join(', ')
create_remote_file(master, "#{testdir}/site.pp", <<-PP)
node default {
  include apache
}
PP

create_remote_file(master, "#{testdir}/modules/apache/manifests/init.pp", <<-PP)
class apache {
  $port = hiera('port')

  notify { "port from hiera":
    message => "apache server port: ${port}"
  }
}
PP

on master, "chown -R #{master['user']}:#{master['group']} #{testdir}"
on master, "chmod -R g+rwX #{testdir}"


step "Try to lookup string data"

master_opts = {
  'main' => {
    'manifest' => "#{testdir}/site.pp",
    'modulepath' => "#{testdir}/modules",
  },
  'master' => {
    'node_terminus' => 'plain',
  }
}

with_puppet_running_on master, master_opts, testdir do
  agents.each do |agent|
    on(agent, puppet('agent', "--no-daemonize --onetime --verbose --server #{master}"))

    assert_match("apache server port: 8080", stdout)
  end
end


ensure step "Teardown"

on master, "if [ -f #{master['puppetpath']}/hiera.conf.bak ]; then mv -f #{master['puppetpath']}/hiera.conf.bak #{master['puppetpath']}/hiera.yaml; fi"

end
