test_name "puppet apply should pluginsync"

step "Create some modules in the modulepath"
basedir = '/tmp/acceptance_pluginsync_modules'
on agents, "rm -rf #{basedir}"

on agents, "mkdir -p #{basedir}/1/a/lib/ #{basedir}/2/a/lib"

create_remote_file(agents, "#{basedir}/1/a/lib/foo.rb", "#1a")
create_remote_file(agents, "#{basedir}/2/a/lib/foo.rb", "#2a")
on agents, puppet_apply("--modulepath=#{basedir}/1:#{basedir}/2 --pluginsync -e 'notify { \"hello\": }'") do
  agents.each do |agent|
    on agent, "cat #{agent['puppetvardir']}/lib/foo.rb"
    assert_match(/#1a/, stdout, "The synced plugin was not found or the wrong version was synced")

    on agent, "rm -f #{agent['puppetvardir']}/lib/foo.rb"
  end
end

on agents, "rm -rf #{basedir}"
