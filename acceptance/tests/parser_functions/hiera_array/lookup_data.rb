test_name "Lookup data using the hiera_array parser function"

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
    port: '8080'
    ntpservers: ['global.ntp.puppetlabs.com']
  ",
  mode => "0640";
}

file { '#{testdir}/hieradata/production.yaml':
  ensure  => file,
  content => "---
    ntpservers: ['production.ntp.puppetlabs.com']
  ",
  mode => "0640";
}

file {
  '#{testdir}/environments/production/modules/ntp':;
  '#{testdir}/environments/production/modules/ntp/manifests':;
}

file { '#{testdir}/environments/production/modules/ntp/manifests/init.pp':
  ensure => file,
  content => '
    class ntp {
      $ntpservers = hiera_array("ntpservers")

      define print {
        $server = $name
        notify { "ntpserver ${server}": }
      }

      ntp::print { $ntpservers: }
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

step "Try to lookup array data"

master_opts = {
  'main' => {
    'environmentpath' => "#{testdir}/environments",
    'hiera_config' => "#{testdir}/hiera.yaml",
  },
}

with_puppet_running_on master, master_opts, testdir do
  agents.each do |agent|
    on(agent, puppet('agent', "-t --server #{master}"), :acceptable_exit_codes => [2])

    assert_match("ntpserver global.ntp.puppetlabs.com", stdout)
    assert_match("ntpserver production.ntp.puppetlabs.com", stdout)
  end
end
