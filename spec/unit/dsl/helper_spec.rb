require 'spec_helper'
require 'puppet_spec/dsl'

require 'puppet/dsl/helper'

include PuppetSpec::DSL

describe Puppet::DSL::Helper do
  before :each do
    @helper = mock
    @helper.extend Puppet::DSL::Helper
  end

  it "should define class methods too" do
    class A
      include Puppet::DSL::Helper
    end

    A.new.should respond_to :is_ruby_dsl?
    A.should     respond_to :is_ruby_dsl?
  end

  describe "#is_ruby_dsl?" do
    it "returns true when Ruby filename is passed as an argument" do
      @helper.is_ruby_dsl?("test.rb").should be true
    end

    it "returns false when not Ruby filename is passed as an argument" do
      @helper.is_ruby_dsl?("test").should be false
    end
  end

  describe "#is_puppet_dsl?" do

    it "returns true when Puppet filename is passed as an argument" do
      @helper.is_puppet_dsl?("test.pp").should be true
    end

    it "returns true when non-Puppet filename is passed as an argument" do
      @helper.is_puppet_dsl?("test").should be true
    end

    it "returns false when Ruby filename is passed as an argument" do
      @helper.is_puppet_dsl?("test.rb").should be false
    end
  end

  describe "#canonize_type" do
    it "should return canonical type name" do
      ["FiLe", "fIlE", "fILE", "File", "file", "FILE"].each do |f|
        @helper.canonize_type(f).should == "File"
      end
    end
  end


  describe "#silence_backtrace" do
    it "executes the block of code" do
      test = nil
      @helper.silence_backtrace { test = true }
      test.should be true
    end

    it "raises Puppet::Error when exception within a block is raised" do
      lambda do
        @helper.silence_backtrace { raise }
      end.should raise_error Puppet::Error
    end

    it "sets Puppet::Error message from the exception" do
      message = "foobarbaz"
      lambda do
        @helper.silence_backtrace { raise message }
      end.should raise_error Puppet::Error, message
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

