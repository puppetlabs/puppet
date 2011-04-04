#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'puppet/application/string_base'
require 'tmpdir'

class Puppet::Application::StringBase::Basetest < Puppet::Application::StringBase
end

describe Puppet::Application::StringBase do
  before :all do
    @dir = Dir.mktmpdir
    $LOAD_PATH.push(@dir)
    FileUtils.mkdir_p(File.join @dir, 'puppet', 'string')
    File.open(File.join(@dir, 'puppet', 'string', 'basetest.rb'), 'w') do |f|
      f.puts "Puppet::String.define(:basetest, '0.0.1')"
    end

    Puppet::String.define(:basetest, '0.0.1') do
      option("--[no-]boolean")
      option("--mandatory MANDATORY")
      option("--optional [OPTIONAL]")

      action :foo do
        option("--action")
        invoke { |*args| args.length }
      end
    end
  end

  after :all do
    FileUtils.remove_entry_secure @dir
    $LOAD_PATH.pop
  end

  let :app do
    app = Puppet::Application::StringBase::Basetest.new
    app.stubs(:exit)
    app.stubs(:puts)
    app.command_line.stubs(:subcommand_name).returns 'subcommand'
    Puppet::Util::Log.stubs(:newdestination)
    app
  end

  describe "#preinit" do
    before :each do
      app.command_line.stubs(:args).returns %w{}
    end

    describe "parsing the command line" do
      context "with just an action" do
        before :all do
          app.command_line.stubs(:args).returns %w{foo}
          app.preinit
        end

        it "should set the string based on the type" do
          app.string.name.should == :basetest
        end

        it "should set the format based on the string default" do
          app.format.should == :pson
        end

        it "should find the action" do
          app.action.should be
          app.action.name.should == :foo
        end
      end

      it "should fail if no action is given" do
        expect { app.preinit }.
          should raise_error ArgumentError, /No action given/
      end

      it "should report a sensible error when options with = fail" do
        app.command_line.stubs(:args).returns %w{--action=bar foo}
        expect { app.preinit }.
          should raise_error ArgumentError, /Unknown option "--action"/
      end

      it "should fail if an action option is before the action" do
        app.command_line.stubs(:args).returns %w{--action foo}
        expect { app.preinit }.
          should raise_error ArgumentError, /Unknown option "--action"/
      end

      it "should fail if an unknown option is before the action" do
        app.command_line.stubs(:args).returns %w{--bar foo}
        expect { app.preinit }.
          should raise_error ArgumentError, /Unknown option "--bar"/
      end

      it "should not fail if an unknown option is after the action" do
        app.command_line.stubs(:args).returns %w{foo --bar}
        app.preinit
        app.action.name.should == :foo
        app.string.should_not be_option :bar
        app.action.should_not be_option :bar
      end

      it "should accept --bar as an argument to a mandatory option after action" do
        app.command_line.stubs(:args).returns %w{foo --mandatory --bar}
        app.preinit and app.parse_options
        app.action.name.should == :foo
        app.options.should == { :mandatory => "--bar" }
      end

      it "should accept --bar as an argument to a mandatory option before action" do
        app.command_line.stubs(:args).returns %w{--mandatory --bar foo}
        app.preinit and app.parse_options
        app.action.name.should == :foo
        app.options.should == { :mandatory => "--bar" }
      end
    end
  end

  describe "#setup" do
    it "should remove the action name from the arguments" do
      app.command_line.stubs(:args).returns %w{--mandatory --bar foo}
      app.preinit and app.parse_options and app.setup
      app.arguments.should == [{ :mandatory => "--bar" }]
    end
  end

  describe "#main" do
    before do
      app.string    = Puppet::String[:basetest, '0.0.1']
      app.action    = app.string.get_action(:foo)
      app.format    = :pson
      app.arguments = ["myname", "myarg"]
    end

    it "should send the specified verb and name to the string" do
      app.string.expects(:foo).with(*app.arguments)
      app.main
    end

    it "should use its render method to render any result" do
      app.expects(:render).with(app.arguments.length + 1)
      app.main
    end
  end
end
