module Spec
  module Expectations
    module StringHelpers
      def starts_with?(prefix)
        to_s[0..(prefix.length - 1)] == prefix
      end
    end
  end
end

class String
  include Spec::Expectations::StringHelpers
end

class Symbol
  include Spec::Expectations::StringHelpers
end