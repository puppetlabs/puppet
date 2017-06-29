# In 2.6, compile does not fail when site.pp does not exist.
#
# However, if a catalog is compiled when site.pp does not exist,
# puppetmaster does not detect when site.pp is created. This requires a restart
#
test_name "Ticket 5477, Puppet Master does not detect newly created site.pp file"

tag 'audit:medium',
    'audit:integration',
    'audit:refactor',     # Use block style `test_name`
    'server'

testdir = master.tmpdir('missing_site_pp')
manifest_file = "#{testdir}/environments/production/manifests/site.pp"

apply_manifest_on(master, <<-PP, :catch_failures => true)
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
}
PP

master_opts = {
  'main' => {
    'environmentpath' => "#{testdir}/environments",
    'filetimeout' => 1,
    'environment_timeout' => 0,
  }
}

with_puppet_running_on master, master_opts, testdir do
  # Run test on Agents
  step "Agent: agent --test"
  on(agents, puppet('agent', "-t --server #{master}"), :acceptable_exit_codes => [0,2])

  # Create a new site.pp
  step "Master: create basic site.pp file"
  create_remote_file master, manifest_file, "notify{ticket_5477_notify:}"

  on master, "chmod 644 #{manifest_file}"

  sleep 3

  step "Agent: puppet agent --test"

  agents.each do |host|
    on(host, puppet('agent', "-t --server #{master}"), :acceptable_exit_codes => [2]) do
      assert_match(/ticket_5477_notify/, stdout, "#{host}: Site.pp not detected on Puppet Master")
    end
  end
end
