require 'spec_helper'
require 'puppet_spec/dsl'

require 'puppet/dsl/helper'

include PuppetSpec::DSL

describe Puppet::DSL::Helper do
  before :each do
    @helper = mock
    @helper.extend Puppet::DSL::Helper
  end

  describe "#is_ruby_filename?" do
    it "returns true when Ruby filename is passed as an argument" do
      @helper.is_ruby_filename?("test.rb").should be true
    end

    it "returns false when not Ruby filename is passed as an argument" do
      @helper.is_ruby_filename?("test").should be false
    end
  end

  describe "#is_puppet_filename?" do

    it "returns true when Puppet filename is passed as an argument" do
      @helper.is_puppet_filename?("test.pp").should be true
    end

    it "returns false when non-Puppet filename is passed as an argument" do
      @helper.is_puppet_filename?("test").should be false
    end
  end

  describe "#canonicalize_type" do
    it "should return canonical type name" do
      ["FiLe", "fIlE", "fILE", "File", "file", "FILE"].each do |f|
        @helper.canonicalize_type(f).should == "File"
      end
    end
  end

  describe "#silence_backtrace" do
    it "executes the block of code" do
      test = nil
      @helper.silence_backtrace { test = true }
      test.should be true
    end

    it "reraises exception when exception within a block is raised" do
      class TestError < Exception; end
      lambda do
        @helper.silence_backtrace { raise TestError.new }
      end.should raise_error TestError
    end

    it "filters the original backtrace" do
      exception = Exception.new
      exception.set_backtrace ["lib/puppet", "bin/puppet"]
      begin
        @helper.silence_backtrace { raise exception }
      rescue Exception => e
        e.backtrace.should == []
      end
    end

  end
end

