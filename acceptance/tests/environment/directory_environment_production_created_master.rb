test_name 'ensure production environment created by master if missing'

testdir = create_tmpdir_for_user master, 'prod-env-created'

step 'make environmentpath'
master_user = on(master, puppet("master --configprint user")).stdout.strip
apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
File {
  ensure => directory,
  owner => #{master_user},
  group => #{master['group']},
  mode => '0770',
}

file {
  "#{testdir}":;
  "#{testdir}/environments":
    ensure => directory,
    mode => '0640',
  ;
}
MANIFEST

master_opts = {
  'master' => {
    'environmentpath' => "#{testdir}/environments",
  }
}

step 'run master; ensure production environment created'
with_puppet_running_on(master, master_opts, testdir) do
  on(master, "test -d '#{testdir}/environments/production'")

  step 'ensure catalog returned from production env with no changes'
  agents.each do |agent|
    on(agent, puppet("agent -t --server #{master} --environment production --detailed-exitcodes")) do
      # detailed-exitcodes produces a 0 when no changes are made.
      assert_equal(0, exit_code)
      assert_match(/Applied catalog/, stdout)
    end
  end
end
