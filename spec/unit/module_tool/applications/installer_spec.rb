require 'spec_helper'

describe Puppet::Module::Tool::Applications::Installer do

  # install single module
  # module with multiple levels of dependencies
  # module with circular dependencies
  #   version mismatch - boom
  #     foo > 2 -> bar > 2
  #     bar -> foo < 2
  #   no mismatch - should be fine
  #     foo > 2 -> bar > 2
  #     bar > 2 -> foo > 2
  # dependency conflicts as a install
  #   remote foo -> bar > 2 -> baz
  #       -> bing -> bar > 2 < 3 -> baz
  #   local bong -> bar > 2.2
  #
  #   foo {
  #
  #   }
  #   bar {
  #     deps_on_me => > 2 < 3 > 2.2
  #     versions {
  #       2.0
  #       2.5 deps => baz
  #       (server not send maybe) 5.0 deps => baz
  #     }
  #   }
  #
  #   bing {
  #     deps_on_me => foo
  #     versions {
  #       1.0 deps => bar >2 < 3
  #     }
  #   }
  # module with remote dependency constraints that don't work with already installed modules
  #   foo -> bar > 2
  #   bar 1.1 already installed
  #   baz already installed -> bar < 2


  it "should install a specific version"
  it "should prompt to overwrite"
  it "should output warnings"
end
