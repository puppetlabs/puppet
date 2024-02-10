test_name 'ensure production environment created by master if missing'

tag 'audit:high',
    'audit:integration',
    'server'

testdir = create_tmpdir_for_user master, 'prod-env-created'

step 'make environmentpath'
master_user = puppet_config(master, 'user', section: 'master')
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
  on(master, "test -d '#{testdir}/environments/production'")

  step 'ensure catalog returned from production env with no changes'
  agents.each do |agent|
    on(agent, puppet("agent -t --environment production --detailed-exitcodes")) do |result|
      # detailed-exitcodes produces a 0 when no changes are made.
      assert_equal(0, result.exit_code)
    end
  end
end
