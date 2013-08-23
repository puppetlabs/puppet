begin test_name "Lookup data using the hiera parser function"

testdir = master.tmpdir('hiera')

step 'Setup'
on master, "mkdir -p #{testdir}/hieradata"
on master, "if [ -f #{master['puppetpath']}/hiera.yaml ]; then cp #{master['puppetpath']}/hiera.yaml #{master['puppetpath']}/hiera.yaml.bak; fi"

apply_manifest_on master, <<-PP
file { '#{testdir}/hiera.yaml':
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

file { '#{testdir}/hieradata':
  ensure  => directory,
  recurse => true,
  purge   => true,
  force   => true,
}
PP

apply_manifest_on master, <<-PP
file { '#{testdir}/hieradata/global.yaml':
  ensure  => present,
  content => "---
    database_user:
      name: postgres
      uid: 500
      gid: 500
  "
}

file { '#{testdir}/hieradata/production.yaml':
  ensure  => present,
  content => "---
    database_user:
      shell: '/bin/bash'
  "
}

PP

on master, "mkdir -p #{testdir}/modules/ntp/manifests"

agent_names = agents.map { |agent| "'#{agent.to_s}'" }.join(', ')
create_remote_file(master, "#{testdir}/site.pp", <<-PP)
node default {
  include ntp
}
PP

create_remote_file(master, "#{testdir}/modules/ntp/manifests/init.pp", <<-PP)
class ntp {
  $database_user = hiera_hash('database_user')

  notify { "the database user":
    message => "name: ${database_user['name']} shell: ${database_user['shell']}"
  }
}
PP

on master, "chown -R #{master['user']}:#{master['group']} #{testdir}"
on master, "chmod -R g+rwX #{testdir}"
on master, "cat #{testdir}/hiera.yaml > #{master['puppetpath']}/hiera.yaml"


step "Try to lookup hash data"

master_opts = {
  'master' => {
    'manifest' => "#{testdir}/site.pp",
    'modulepath' => "#{testdir}/modules",
    'node_terminus' => 'plain',
  }
}

with_puppet_running_on master, master_opts, testdir do
  agents.each do |agent|
    on(agent, puppet('agent', "--no-daemonize --onetime --verbose --server #{master}"))

    assert_match("name: postgres shell: /bin/bash", stdout)
  end
end


ensure step "Teardown"

on master, "if [ -f #{master['puppetpath']}/hiera.conf.bak ]; then " +
             "cat #{master['puppetpath']}/hiera.conf.bak > #{master['puppetpath']}/hiera.yaml; " +
             "rm -rf #{master['puppetpath']}/hiera.yaml.bak; " +
           "fi"

end
