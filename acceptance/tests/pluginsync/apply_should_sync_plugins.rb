test_name "puppet apply should pluginsync"

require 'puppet/acceptance/temp_file_utils'
extend Puppet::Acceptance::TempFileUtils

initialize_temp_dirs()

step "Create some modules in the modulepath"
basedir = 'tmp_acceptance_pluginsync_modules'
module1libdir = "#{basedir}/1"
module2libdir = "#{basedir}/2"

agents.each do |agent|
  create_test_file(agent, "#{module1libdir}/a/lib/foo.rb", "#1a", :mkdirs => true)
  create_test_file(agent, "#{module2libdir}/b/lib/foo.rb", "#2a", :mkdirs => true)

  on agent, puppet_apply("--modulepath=#{get_test_file_path(agent, module1libdir)}:#{get_test_file_path(agent, module2libdir)} --pluginsync -e 'notify { \"hello\": }'")

  on agent, "cat #{agent['puppetvardir']}/lib/foo.rb" do
    assert_match(/#1a/, stdout, "The synced plugin was not found or the wrong version was synced")
  end
end

remove_temp_dirs()
