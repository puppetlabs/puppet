test_name 'C99627: can use Object types in the catalog and apply/agent' do
  require 'puppet/acceptance/environment_utils.rb'
  extend Puppet::Acceptance::EnvironmentUtils

tag 'audit:high',
    'audit:integration',
    'audit:refactor'     # The use of apply on a reference system should
                         # be adequate to test puppet. Running this in
                         # context of server/agent should not be necessary.

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

  agents.each do |agent|
    # This is currently only expected to work with apply as the custom data type
    # definition will not be present on the agent to deserialize properly

    step "apply manifest on agent #{agent.hostname} and assert notify output" do
      apply_manifest_on(agent, manifest) do |result|
        assert(result.exit_code == 0, "agent didn't exit properly: (#{result.exit_code})")
        assert_match(/A foo/, result.stdout, 'agent didn\'t notify correctly')
      end
    end
  end

end
