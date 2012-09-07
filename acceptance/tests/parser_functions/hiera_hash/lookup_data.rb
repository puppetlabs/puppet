begin test_name "Lookup data using the hiera parser function"

step 'Setup'
on master, "mkdir -p /var/lib/hiera"

apply_manifest_on master, <<-PP
file { '/etc/puppet/hiera.yaml':
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
      :datadir: "/var/lib/hiera"
  '
}

file { '/var/lib/hiera':
  ensure  => directory,
  recurse => true,
  purge   => true,
  force   => true,
}
PP

apply_manifest_on master, <<-PP
file { '/var/lib/hiera/global.yaml':
  ensure  => present,
  content => "---
    database_user:
      name: postgres
      uid: 500
      gid: 500
  "
}

file { '/var/lib/hiera/production.yaml':
  ensure  => present,
  content => "---
    database_user:
      shell: '/bin/bash'
  "
}

PP

testdir = master.tmpdir('hiera')

create_remote_file(master, "#{testdir}/puppet.conf", <<END)
[main]
  manifest   = "#{testdir}/site.pp"
  modulepath = "#{testdir}/modules"
END

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

on master, "chown -R root:puppet #{testdir}"
on master, "chmod -R g+rwX #{testdir}"


step "Try to lookup hash data"

with_master_running_on(master, "--config #{testdir}/puppet.conf --debug --verbose --daemonize --dns_alt_names=\"puppet,$(facter hostname),$(facter fqdn)\" --autosign true") do
  agents.each do |agent|
    run_agent_on(agent, "--no-daemonize --onetime --verbose --server #{master}")

    assert_match("name: postgres shell: /bin/bash", stdout)
  end
end


ensure step "Teardown"
apply_manifest_on master, <<-PP
file { '/var/lib/hiera':
  ensure  => directory,
  recurse => true,
  purge   => true,
  force   => true,
}
PP
end
