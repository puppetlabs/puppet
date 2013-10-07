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

user = master.execute('puppet config print user')
group = master.execute('puppet config print group')

on master, "chown -R #{user}:#{group} #{testdir}"
on master, "chmod -R g+rwX #{testdir}"

master_opts = {
  :master => {
    :manifest => "#{testdir}/site.pp",
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
