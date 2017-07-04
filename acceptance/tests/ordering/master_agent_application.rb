test_name "Puppet applies resources without dependencies in file order over the network"

tag 'audit:medium',
    'audit:integration',
    'server'

testdir = master.tmpdir('application_order')

apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
  File {
    ensure => directory,
    mode => "0750",
    owner => #{master.puppet['user']},
    group => #{master.puppet['group']},
  }
  file {
    '#{testdir}':;
    '#{testdir}/environments':;
    '#{testdir}/environments/production':;
    '#{testdir}/environments/production/manifests':;
    '#{testdir}/environments/production/manifests/site.pp':
      ensure => file,
      mode => "0640",
      content => '
notify { "first": }
notify { "second": }
notify { "third": }
notify { "fourth": }
notify { "fifth": }
notify { "sixth": }
notify { "seventh": }
notify { "eighth": }
      ';
  }
MANIFEST

master_opts = {
  'main' => {
    'environmentpath' => "#{testdir}/environments",
   }
}

with_puppet_running_on(master, master_opts) do
  agents.each do |agent|
    on(agent, puppet('agent', "--no-daemonize --onetime --verbose --server #{master} --ordering manifest"))
    if stdout !~ /Notice: first.*Notice: second.*Notice: third.*Notice: fourth.*Notice: fifth.*Notice: sixth.*Notice: seventh.*Notice: eighth/m
      fail_test "Output did not include the notify resources in the correct order"
    end
  end
end
