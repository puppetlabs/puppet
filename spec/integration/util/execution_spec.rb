require 'spec_helper'

describe Puppet::Util::Execution do
  include PuppetSpec::Files

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

  describe "#execute (Windows)", :if => Puppet.features.microsoft_windows? do
    let(:utf8text) do
      # Japanese Lorem Ipsum snippet
      "utf8testfile" + [227, 131, 171, 227, 131, 147, 227, 131, 179, 227, 131, 132, 227,
                        130, 162, 227, 130, 166, 227, 130, 167, 227, 131, 150, 227, 130,
                        162, 227, 129, 181, 227, 129, 185, 227, 129, 139, 227, 130, 137,
                        227, 129, 154, 227, 130, 187, 227, 130, 183, 227, 131, 147, 227,
                        131, 170, 227, 131, 134].pack('c*').force_encoding(Encoding::UTF_8)
    end
    let(:temputf8filename) do
      script_containing(utf8text, :windows => "@ECHO OFF\nECHO #{utf8text}\nEXIT 100")
    end

    it "should execute with non-english characters in command line" do
      result = Puppet::Util::Execution.execute("cmd /c \"#{temputf8filename}\"", :failonfail => false)
      expect(temputf8filename.encoding.name).to eq('UTF-8')
      expect(result.exitstatus).to eq(100)
    end
  end
end
