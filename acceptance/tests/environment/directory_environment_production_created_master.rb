test_name 'ensure production environment created by master if missing'

tag 'audit:medium',
    'audit:integration',
    'server'

testdir = create_tmpdir_for_user master, 'prod-env-created'

step 'make environmentpath'
master_user = on(master, puppet("master --configprint user")).stdout.strip
cert_path   = on(master, puppet('config', 'print', 'hostcert')).stdout.strip
key_path    = on(master, puppet('config', 'print', 'hostprivkey')).stdout.strip
cacert_path = on(master, puppet('config', 'print', 'localcacert')).stdout.strip
apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
File {
  ensure => directory,
  owner => #{master_user},
  group => #{master.puppet['group']},
  mode => '0640',
}

file {
  "#{testdir}":;
  "#{testdir}/environments":;
}
MANIFEST

master_opts = {
  'main' => {
    'environmentpath' => "#{testdir}/environments",
  }
}

step 'run master; ensure production environment created'
with_puppet_running_on(master, master_opts, testdir) do
  if master.is_using_passenger?
    on(master, "curl -k --cert #{cert_path} --key #{key_path} --cacert #{cacert_path} https://localhost:8140/puppet/v3/environments")
  end
  on(master, "test -d '#{testdir}/environments/production'")

  step 'ensure catalog returned from production env with no changes'
  agents.each do |agent|
    on(agent, puppet("agent -t --server #{master} --environment production --detailed-exitcodes")) do
      # detailed-exitcodes produces a 0 when no changes are made.
      assert_equal(0, exit_code)
    end
  end
end
