test_name "puppet apply should pluginsync"


require 'puppet/acceptance/temp_file_utils'

extend Puppet::Acceptance::TempFileUtils

initialize_temp_dirs()

all_tests_passed = false


step "Create some modules in the modulepath"
basedir = 'tmp_acceptance_pluginsync_modules'
module1libdir = "#{basedir}/1/a/lib"
module2libdir = "#{basedir}/2/a/lib"


begin
  agents.each do |agent|
    create_test_file(agent, get_test_file_path(agent, "#{module1libdir}/foo.rb"), "#1a", :mkdirs => true)
    create_test_file(agent, get_test_file_path(agent, "#{module2libdir}//foo.rb"), "#2a", :mkdirs => true)

    on agent, puppet_apply("--modulepath=#{get_test_file_path(agent, "#{basedir}/1")}:#{get_test_file_path(agent, "#{basedir}/2")} --pluginsync -e 'notify { \"hello\": }'")

    agent.execute("cat #{agent['puppetvardir']}/lib/foo.rb", {}) do
      assert_match(/#1a/, stdout, "The synced plugin was not found or the wrong version was synced")
    end
  end
  all_tests_passed = true
ensure

##########################################################################################
# Clean up all of the temp files created by this test.  It would be nice if this logic
# could be handled outside of the test itself; I envision a stanza like this one appearing
# in a very large number of the tests going forward unless it is handled by the framework.
##########################################################################################
  if all_tests_passed then
    remove_temp_dirs()
  end
end
