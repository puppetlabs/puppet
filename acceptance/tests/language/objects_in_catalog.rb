test_name 'C99627: can use Object types in the catalog and apply/agent' do
  require 'puppet/acceptance/environment_utils.rb'
  extend Puppet::Acceptance::EnvironmentUtils

tag 'audit:high',
    'audit:integration',
    'audit:refactor'     # The use of apply on a reference system should
                         # be adequate to test puppet. Running this in
                         # context of server/agent should not be necessary.

  app_type        = File.basename(__FILE__, '.*')
  tmp_environment = mk_tmp_environment_with_teardown(master, app_type)
  fq_tmp_environmentpath  = "#{environmentpath}/#{tmp_environment}"

  manifest = <<-PP
type Mod::Foo = Object[{
  attributes => {
    'name' => String,
    'size' => Integer[0, default]
  }
}]
define mod::foo_notifier(Mod::Foo $foo) {
   notify { $foo.name: }
}
class mod {
  mod::foo_notifier { xyz:
    foo => Mod::Foo('A foo', 42)
  }
}
include mod
  PP

  step 'create a site.pp with custom type, object and notify' do
    create_sitepp(master, tmp_environment, manifest)
  end

  with_puppet_running_on(master,{}) do
    agents.each do |agent|
      step "run the agent on #{agent.hostname} and assert notify output" do
        on(agent, puppet('agent', "-t --server #{master.hostname} --environment #{tmp_environment}"),
           :accept_all_exit_codes => true) do |result|
          assert(result.exit_code == 2, "agent didn't exit properly: (#{result.exit_code})")
          assert_match(/A foo/, result.stdout, 'agent didn\'t notify correctly')
        end
      end

      step "apply manifest on agent #{agent.hostname} and assert notify output" do
        apply_manifest_on(agent, manifest) do |result|
          assert(result.exit_code == 0, "agent didn't exit properly: (#{result.exit_code})")
          assert_match(/A foo/, result.stdout, 'agent didn\'t notify correctly')
        end
      end
    end
  end

end
