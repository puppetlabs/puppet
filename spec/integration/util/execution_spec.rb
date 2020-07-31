require 'spec_helper'

describe Puppet::Util::Execution, unless: Puppet::Util::Platform.jruby? do
  include PuppetSpec::Files

  describe "#execpipe" do
    it "should set LANG to C avoid localized output", :if => !Puppet::Util::Platform.windows? do
      out = ""
      Puppet::Util::Execution.execpipe('echo $LANG'){ |line| out << line.read.chomp }
      expect(out).to eq("C")
    end

    it "should set LC_ALL to C avoid localized output", :if => !Puppet::Util::Platform.windows? do
      out = ""
      Puppet::Util::Execution.execpipe('echo $LC_ALL'){ |line| out << line.read.chomp }
      expect(out).to eq("C")
    end

    it "should raise an ExecutionFailure with a missing command and :failonfail set to true" do
      expect {
        failonfail = true
        # NOTE: critical to return l in the block for `output` in method to be #<IO:(closed)>
        Puppet::Util::Execution.execpipe('conan_the_librarion', failonfail) { |l| l }
      }.to raise_error(Puppet::ExecutionFailure)
    end
  end

  describe "#execute" do
    if Puppet::Util::Platform.windows?
      let(:argv) { ["cmd", "/c", "echo", 123] }
    else
      let(:argv) { ["echo", 123] }
    end

    it 'stringifies sensitive arguments when given an array containing integers' do
      result = Puppet::Util::Execution.execute(argv, sensitive: true)
      expect(result.to_s.strip).to eq("123")
      expect(result.exitstatus).to eq(0)
    end

    it 'redacts sensitive arguments when given an array' do
      Puppet[:log_level] = :debug
      Puppet::Util::Execution.execute(argv, sensitive: true)
      expect(@logs).to include(an_object_having_attributes(level: :debug, message: "Executing: '[redacted]'"))
    end

    it 'redacts sensitive arguments when given a string' do
      Puppet[:log_level] = :debug
      str = argv.map(&:to_s).join(' ')
      Puppet::Util::Execution.execute(str, sensitive: true)
      expect(@logs).to include(an_object_having_attributes(level: :debug, message: "Executing: '[redacted]'"))
    end

    it "allows stdout and stderr to share a file" do
      command = "ruby -e '(1..10).each {|i| (i%2==0) ? $stdout.puts(i) : $stderr.puts(i)}'"

      expect(Puppet::Util::Execution.execute(command, :combine => true).split).to match_array([*'1'..'10'])
    end

    it "returns output and set $CHILD_STATUS" do
      command = "ruby -e 'puts \"foo\"; exit 42'"

      output = Puppet::Util::Execution.execute(command, {:failonfail => false})

      expect(output).to eq("foo\n")
      expect($CHILD_STATUS.exitstatus).to eq(42)
    end

    it "raises an error if non-zero exit status is returned" do
      command = "ruby -e 'exit 43'"

      expect { Puppet::Util::Execution.execute(command) }.to raise_error(Puppet::ExecutionFailure, /Execution of '#{command}' returned 43: /)
      expect($CHILD_STATUS.exitstatus).to eq(43)
    end
  end

  describe "#execute (non-Windows)", :if => !Puppet::Util::Platform.windows? do
    it "should execute basic shell command" do
      result = Puppet::Util::Execution.execute("ls /tmp", :failonfail => true)
      expect(result.exitstatus).to eq(0)
      expect(result.to_s).to_not be_nil
    end
  end

  describe "#execute (Windows)", :if => Puppet::Util::Platform.windows? do
    let(:utf8text) do
      # Japanese Lorem Ipsum snippet
      "utf8testfile" + [227, 131, 171, 227, 131, 147, 227, 131, 179, 227, 131, 132, 227,
                        130, 162, 227, 130, 166, 227, 130, 167, 227, 131, 150, 227, 130,
                        162, 227, 129, 181, 227, 129, 185, 227, 129, 139, 227, 130, 137,
                        227, 129, 154, 227, 130, 187, 227, 130, 183, 227, 131, 147, 227,
                        131, 170, 227, 131, 134].pack('c*').force_encoding(Encoding::UTF_8)
    end
    let(:temputf8filename) do
      script_containing(utf8text, :windows => "@ECHO OFF\r\nECHO #{utf8text}\r\nEXIT 100")
    end

    it "should execute with non-english characters in command line" do
      result = Puppet::Util::Execution.execute("cmd /c \"#{temputf8filename}\"", :failonfail => false)
      expect(temputf8filename.encoding.name).to eq('UTF-8')
      expect(result.exitstatus).to eq(100)
    end
  end
end
