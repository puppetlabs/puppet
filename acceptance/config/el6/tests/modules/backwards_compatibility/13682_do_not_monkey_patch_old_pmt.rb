begin
  test_name "puppet module should not monkey patch puppet-module"
  step "Simulate the behavior of puppet-module"
  puppet_module = <<-'PUPPET_MODULE'
ruby -e '
module Puppet
  class Module
    module Tool
      REPOSITORY_URL=1
    end
  end
end
require "puppet"
puts Puppet.version
'
PUPPET_MODULE
  on(master, puppet_module) do
    # If we monkey patch the existing puppet-module Gem then Ruby will issue a
    # warning about redefined constants.  This is not a comprehensive test but
    # it should catch the majority of regressions.
    assert_no_match(/warning/, stderr)
  end
end
