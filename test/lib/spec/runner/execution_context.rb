module Spec
  module Runner
    class ExecutionContext
      module InstanceMethods
        def initialize(*args) #:nodoc:
          #necessary for RSpec's own specs
        end
        
        def violated(message="")
          raise Spec::Expectations::ExpectationNotMetError.new(message)
        end

      end
      include InstanceMethods
    end
  end
end