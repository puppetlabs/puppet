require 'autotest'
require 'autotest/rspec'

class Autotest::PuppetRspec < Autotest::Rspec
  def initialize # :nodoc:
    super
    @test_mappings = {
        %r%^spec/(unit|integration)/.*\.rb$% => proc { |filename, _|
          filename
        },
    }
  end
end
