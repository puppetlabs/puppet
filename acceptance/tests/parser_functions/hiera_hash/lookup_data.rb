test_name "Lookup data using the hiera_hash parser function"

tag 'audit:medium',
    'audit:acceptance',
    'audit:refactor'    # Master is not required for this test. Replace with agents.each

testdir = master.tmpdir('hiera')

step 'Setup'

apply_manifest_on(master, <<-PP, :catch_failures => true)
File {
  ensure => directory,
  mode => "0750",
  owner => #{master.puppet['user']},
  group => #{master.puppet['group']},
}
file {
  '#{testdir}':;
  '#{testdir}/hieradata':;
  '#{testdir}/environments':;
  '#{testdir}/environments/production':;
  '#{testdir}/environments/production/manifests':;
  '#{testdir}/environments/production/modules':;
}

file { '#{testdir}/hiera.yaml':
  ensure  => file,
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
  ',
  mode => "0640";
}

file { '#{testdir}/hieradata/global.yaml':
  ensure  => file,
  content => "---
    database_user:
      name: postgres
      uid: 500
      gid: 500
  ",
  mode => "0640";
}

file { '#{testdir}/hieradata/production.yaml':
  ensure  => file,
  content => "---
    database_user:
      shell: '/bin/bash'
  ",
  mode => "0640";
}

file {
  '#{testdir}/environments/production/modules/ntp/':;
  '#{testdir}/environments/production/modules/ntp/manifests':;
}

file { '#{testdir}/environments/production/modules/ntp/manifests/init.pp':
  ensure => file,
  content => 'class ntp {
    $database_user = hiera_hash("database_user")

    notify { "the database user":
      message => "name: ${database_user["name"]} shell: ${database_user["shell"]}"
    }
  }',
  mode => "0640";
}

file { '#{testdir}/environments/production/manifests/site.pp':
  ensure => file,
  content => "
    node default {
      include ntp
    }",
  mode => "0640";
}
PP

step "Try to lookup hash data"

master_opts = {
  'main' => {
    'environmentpath' => "#{testdir}/environments",
    'hiera_config' => "#{testdir}/hiera.yaml",
  },
}

with_puppet_running_on master, master_opts, testdir do
  agents.each do |agent|
    on(agent, puppet('agent', "-t --server #{master}"), :acceptable_exit_codes => [2])

    assert_match("name: postgres shell: /bin/bash", stdout)
  end
end
