#!/usr/bin/env ruby

require 'spec_helper'

describe Puppet::Util do
  describe "#execute" do
    it "should properly allow stdout and stderr to share a file" do
      command = "ruby -e '(1..10).each {|i| (i%2==0) ? $stdout.puts(i) : $stderr.puts(i)}'"

      Puppet::Util.execute(command, :combine => true).split.should =~ [*'1'..'10']
    end

    it "should return output and set $CHILD_STATUS" do
      command = "ruby -e 'puts \"foo\"; exit 42'"

      output = Puppet::Util.execute(command, {:failonfail => false})

      output.should == "foo\n"
      $CHILD_STATUS.exitstatus.should == 42
    end

    it "should raise an error if non-zero exit status is returned" do
      command = "ruby -e 'exit 43'"

      expect { Puppet::Util.execute(command) }.to raise_error(Puppet::ExecutionFailure, /Execution of '#{command}' returned 43: /)
      $CHILD_STATUS.exitstatus.should == 43
    end
  end
end
