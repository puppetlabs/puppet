require 'spec_helper'

describe Puppet::Util::Execution do
  describe "#execpipe" do
    it "should set LANG to C avoid localized output", :if => !Puppet.features.microsoft_windows? do
      out = ""
      Puppet::Util::Execution.execpipe('echo $LANG'){ |line| out << line.read.chomp }
      expect(out).to eq("C")
    end

    it "should set LC_ALL to C avoid localized output", :if => !Puppet.features.microsoft_windows? do
      out = ""
      Puppet::Util::Execution.execpipe('echo $LC_ALL'){ |line| out << line.read.chomp }
      expect(out).to eq("C")
    end
  end
end
