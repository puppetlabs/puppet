#!/usr/bin/env ruby

require 'spec_helper'

describe Puppet::Util do
  describe "#execute" do
    it "should properly allow stdout and stderr to share a file" do
      command = "ruby -e '(1..10).each {|i| (i%2==0) ? $stdout.puts(i) : $stderr.puts(i)}'"

      Puppet::Util.execute(command, :combine => true).split.should =~ [*'1'..'10']
    end
  end
end
