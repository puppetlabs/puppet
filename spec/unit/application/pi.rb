#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/application/pi'

describe "pi" do
    before :each do
        @pi = Puppet::Application[:pi]
    end

    it "should ask Puppet::Application to not parse Puppet configuration file" do
        @pi.should_parse_config?.should be_false
    end

    it "should declare a main command" do
        @pi.should respond_to(:main)
    end

    it "should declare a preinit block" do
        @pi.should respond_to(:run_preinit)
    end

    [:providers,:list,:meta].each do |option|
        it "should declare handle_#{option} method" do
            @pi.should respond_to("handle_#{option}".to_sym)
        end

        it "should store argument value when calling handle_#{option}" do
            @pi.options.expects(:[]=).with("#{option}".to_sym, 'arg')
            @pi.send("handle_#{option}".to_sym, 'arg')
        end
    end


    describe "in preinit" do
        it "should set options[:parameteers] to true" do
            @pi.run_preinit

            @pi.options[:parameters].should be_true
        end
    end

    describe "when handling parameters" do
        it "should set options[:parameters] to false" do
            @pi.handle_short(nil)

            @pi.options[:parameters].should be_false
        end
    end

    describe "during setup" do
        it "should collect ARGV in options[:types]" do
            ARGV.stubs(:dup).returns(['1','2'])
            @pi.run_setup

            @pi.options[:types].should == ['1','2']
        end
    end

    describe "when running" do

        before :each do
            @typedoc = stub 'type_doc'
            TypeDoc.stubs(:new).returns(@typedoc)
        end

        it "should call list_types if options list is set" do
            @pi.options[:list] = true

            @typedoc.expects(:list_types)

            @pi.run_command
        end

        it "should call format_type for each given types" do
            @pi.options[:list] = false
            @pi.options[:types] = ['type']

            @typedoc.expects(:format_type).with('type', @pi.options)
            @pi.run_command
        end
    end
end
