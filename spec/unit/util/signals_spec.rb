require "spec_helper"

require "puppet/util/signals"

class SignalsTest
  include Puppet::Util::Signals
end

describe Puppet::Util::Signals do
  let(:instance) { SignalsTest.new}

  context "#siginfo_available?" do
    it "returns true if SIGINFO is available" do
      Signal.stubs(:list).returns({"INFO" => "29"})

      expect(instance.siginfo_available?).to be_true
    end

    it "returns false if SIGINFO is not available" do
      Signal.stubs(:list).returns({"INT" => "1"})

      expect(instance.siginfo_available?).to be_false
    end
  end
end
