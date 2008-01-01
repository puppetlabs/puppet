require 'spec/expectations'
require 'spec/matchers'

module Test
  module Unit
    class TestCase
      include Spec::Matchers
    end
  end
end
