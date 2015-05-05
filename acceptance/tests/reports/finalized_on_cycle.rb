test_name "Reports are finalized on resource cycles"

testdir = create_tmpdir_for_user master, 'report_finalized'

apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
  File {
    ensure => directory,
    mode   => '0770',
    owner  => #{master.puppet['user']},
    group  => #{master.puppet['group']},
  }
  file {
    '#{testdir}/environments':;
    '#{testdir}/environments/production':;
    '#{testdir}/environments/production/manifests':;
    '#{testdir}/reports':;
  }
  file { '#{testdir}/environments/production/manifests/site.pp':
    ensure  => file,
    mode    => '0640',
    content => 'notify { "foo": require => Notify["bar"]; "bar": require => Notify["foo"] }'
  }
  file { '#{testdir}/check_report.rb':
    ensure  => file,
    mode    => '0640',
    content => 'require "yaml"; require "puppet"; exit YAML.load_file(ARGV[0]).metrics.empty? ? 1 : 0'
  }
MANIFEST

master_opts = {
  'main' => {
    'environmentpath' => "#{testdir}/environments",
    'reports'         => 'store',
    'reportdir'       => "#{testdir}/reports"
  },
}

ruby = '/opt/puppetlabs/puppet/bin/ruby'
reports = "#{testdir}/reports"
check = "#{testdir}/check_report.rb"

with_puppet_running_on(master, master_opts) do
  agents.each do |agent|
    # We expect the agent to fail here (because of the cycle in the manifest above)
    on(agent, puppet('agent', "-t --server #{master}"), :acceptable_exit_codes => [1])
    on(master, "#{ruby} #{check} #{reports}/#{agent}/*.yaml")
  end
end
