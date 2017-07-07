#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/application/describe'

describe Puppet::Application::Describe do
  before :each do
    @describe = Puppet::Application[:describe]
  end

  it "should declare a main command" do
    expect(@describe).to respond_to(:main)
  end

  it "should declare a preinit block" do
    expect(@describe).to respond_to(:preinit)
  end

  [:providers,:list,:meta].each do |option|
    it "should declare handle_#{option} method" do
      expect(@describe).to respond_to("handle_#{option}".to_sym)
    end

    it "should store argument value when calling handle_#{option}" do
      @describe.options.expects(:[]=).with("#{option}".to_sym, 'arg')
      @describe.send("handle_#{option}".to_sym, 'arg')
    end
  end


  describe "in preinit" do
    it "should set options[:parameters] to true" do
      @describe.preinit

      expect(@describe.options[:parameters]).to be_truthy
    end
  end

  describe "when handling parameters" do
    it "should set options[:parameters] to false" do
      @describe.handle_short(nil)

      expect(@describe.options[:parameters]).to be_falsey
    end
  end

  describe "during setup" do
    it "should collect arguments in options[:types]" do
      @describe.command_line.stubs(:args).returns(['1','2'])
      @describe.setup

      expect(@describe.options[:types]).to eq(['1','2'])
    end
  end

  describe "when running" do

    before :each do
      @typedoc = stub 'type_doc'
      TypeDoc.stubs(:new).returns(@typedoc)
    end

    it "should call list_types if options list is set" do
      @describe.options[:list] = true

      @typedoc.expects(:list_types)

      @describe.run_command
    end

    it "should call format_type for each given types" do
      @describe.options[:list] = false
      @describe.options[:types] = ['type']

      @typedoc.expects(:format_type).with('type', @describe.options)
      @describe.run_command
    end
  end

  it "should format text with long non-space runs without garbling" do
    @f = Formatter.new(76)

    @teststring = <<TESTSTRING
. 12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890 nick@magpie.puppetlabs.lan
**this part should not repeat!**
TESTSTRING

    @expected_result = <<EXPECTED
.
1234567890123456789012345678901234567890123456789012345678901234567890123456
7890123456789012345678901234567890 nick@magpie.puppetlabs.lan
**this part should not repeat!**
EXPECTED

    result = @f.wrap(@teststring, {:indent => 0, :scrub => true})
    expect(result).to eql(@expected_result)
  end
end
