test_name "Puppet applies resources without dependencies in file order over the network"

testdir = master.tmpdir('application_order')


create_remote_file(master, "#{testdir}/site.pp", <<-PP)
notify { "first": }
notify { "second": }
notify { "third": }
notify { "fourth": }
notify { "fifth": }
notify { "sixth": }
notify { "seventh": }
notify { "eighth": }
PP

with_master_running_on(master, "--manifest #{testdir}/site.pp") do
  agents.each do |agent|
    run_agent_on(agent, "--no-daemonize --onetime --verbose --server #{master}")
    if stdout !~ /Notice: first.*Notice: second.*Notice: third.*Notice: fourth.*Notice: fifth.*Notice: sixth.*Notice: seventh.*Notice: eighth/m
      fail_test "Output did not include the notify resources in the correct order"
    end
  end
end
