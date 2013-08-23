# In 2.6, compile does not fail when site.pp does not exist.
#
# However, if a catalog is compiled when site.pp does not exist,
# puppetmaster does not detect when site.pp is created. This requires a restart
#
test_name "Ticket 5477, Puppet Master does not detect newly created site.pp file"

testdir = master.tmpdir('missing_site_pp')
manifest_file = "#{testdir}/site.pp"

on master, "chmod 777 #{testdir}"
on master, "rm -f #{manifest_file}"

master_opts = {
  'master' => {
    'manifest' => manifest_file,
    'node_terminus' => 'plain',
    'filetimeout' => 1
  }
}

with_puppet_running_on master, master_opts, testdir do
  # Run test on Agents
  step "Agent: agent --test"
  on agents, puppet('agent', "--test --server #{master}")

  # Create a new site.pp
  step "Master: create basic site.pp file"
  create_remote_file master, manifest_file, "notify{ticket_5477_notify:}"

  on master, "chmod 644 #{manifest_file}"

  sleep 3

  step "Agent: puppet agent --test"

  agents.each do |host|
    on(host, puppet('agent', "--test --server #{master}"), :acceptable_exit_codes => [2]) do
      assert_match(/ticket_5477_notify/, stdout, "#{host}: Site.pp not detected on Puppet Master")
    end
  end
end
