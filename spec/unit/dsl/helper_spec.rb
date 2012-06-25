require 'spec_helper'
require 'puppet_spec/files'

require 'puppet/dsl/helper'

include PuppetSpec::Files

describe Puppet::DSL::Helper do
  before :each do
    @helper = mock
    @helper.extend Puppet::DSL::Helper
  end

  describe "#dsl_type_for" do

    it "should return :ruby when the manifest name ends with .rb" do
      Puppet[:manifest] = "test.rb"
      @helper.dsl_type_for(nil).should == :ruby
    end

    it "should return :puppet when the manifest name ends with .pp" do
      Puppet[:manifest] = "test.pp"
      @helper.dsl_type_for(nil).should == :puppet
    end

    it "should return :puppet when the manifest name is blank" do
      Puppet[:manifest] = ""
      @helper.dsl_type_for(nil).should == :puppet
    end
  end

  describe "#use_ruby_dsl?" do
    it "should return true when #dsl_type_for returns :ruby" do
      @helper.expects(:dsl_type_for).with(nil).returns :ruby
      @helper.use_ruby_dsl?(nil).should == true
    end

    it "should return false when #dsl_type_for returns :puppet" do
      @helper.expects(:dsl_type_for).with(nil).returns :puppet
      @helper.use_ruby_dsl?(nil).should == false
    end
  end

  describe "#use_puppet_dsl?" do

    it "should return false when #dsl_type_for returns :ruby" do
      @helper.expects(:dsl_type_for).at_least_once.with(nil).returns :ruby
      @helper.use_puppet_dsl?(nil).should be false
    end

    it "should return true when #dsl_type_for returns :puppet" do
      @helper.expects(:dsl_type_for).at_least_once.with(nil).returns :puppet
      @helper.use_puppet_dsl?(nil).should be true
    end

  end

  describe "#get_ruby_code" do

    it "should return :code despite :manifest is set" do
      Puppet[:code] = "test string"
      Puppet[:manifest] = "test.rb"

      @helper.get_ruby_code(nil).should == "test string"
    end

    it "should read the contents of the :manifest" do
      filename = tmpfile ["test", ".rb"]
      File.open filename, "w" do |f|
        f << "test file contents"
      end
      Puppet[:manifest] = filename
      @helper.get_ruby_code(nil).should == "test file contents"
    end

    it "should raise when not using ruby dsl" do
      Puppet[:manifest] = "test.pp"
      lambda do
        @helper.get_ruby_code nil
      end.should raise_error
    end

  end

end

