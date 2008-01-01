require File.dirname(__FILE__) + '/../../../spec_helper.rb'
require 'delegate'

module Bug10577
  class OCI8
    def describe(name)
      "Hello, #{name}"
    end

    def something(name)
      "Something, #{name}"
    end
  end

  class OCI8AutoRecover < DelegateClass(OCI8)
    def initialize
      @connection = OCI8.new
      super(@connection)
    end
  end

  class OCI8AutoRecover
    def describe(name)
      @connection.describe(name)
    end
  end

  describe Kernel do
    it "should not mask a delegate class' describe method" do
      bugger = OCI8AutoRecover.new
      bugger.describe('aslak').should == "Hello, aslak"
      bugger.something('aslak').should == "Something, aslak"
    end
  end
end
