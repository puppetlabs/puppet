require 'stringio'
require 'rbconfig'

dir = File.dirname(__FILE__)
lib_path = File.expand_path("#{dir}/../lib")
$LOAD_PATH.unshift lib_path unless $LOAD_PATH.include?(lib_path)
$_spec_spec = true # Prevents Kernel.exit in various places

require 'spec'
require 'spec/mocks'
require 'hpricot' # Needed to compare generated with wanted HTML
spec_classes_path = File.expand_path("#{dir}/../spec/spec/spec_classes")
require spec_classes_path unless $LOAD_PATH.include?(spec_classes_path)

module Spec
  module Matchers
    def fail
      raise_error(Spec::Expectations::ExpectationNotMetError)
    end

    def fail_with(message)
      raise_error(Spec::Expectations::ExpectationNotMetError, message)
    end

    class Pass
      def matches?(proc, &block)
        begin
          proc.call
          true
        rescue Exception => @error
          false
        end
      end

      def failure_message
        @error.message + "\n" + @error.backtrace.join("\n")
      end
    end

    def pass
      Pass.new
    end
  end
end

class NonStandardError < Exception; end
