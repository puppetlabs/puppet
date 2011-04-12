#!/usr/bin/env rspec

require 'spec_helper'
require 'puppet/application/faces_base'
require 'tmpdir'

class Puppet::Application::FacesBase::Basetest < Puppet::Application::FacesBase
end

describe Puppet::Application::FacesBase do
  before :all do
    Puppet::Faces.define(:basetest, '0.0.1') do
      option("--[no-]boolean")
      option("--mandatory MANDATORY")
      option("--optional [OPTIONAL]")

      action :foo do
        option("--action")
        when_invoked { |*args| args.length }
      end
    end
  end

  let :app do
    app = Puppet::Application::FacesBase::Basetest.new
    app.stubs(:exit)
    app.stubs(:puts)
    app.command_line.stubs(:subcommand_name).returns 'subcommand'
    Puppet::Util::Log.stubs(:newdestination)
    app
  end

  describe "#find_global_settings_argument" do
    it "should not match --ca to --ca-location" do
      option = mock('ca option', :optparse_args => ["--ca"])
      Puppet.settings.expects(:each).yields(:ca, option)

      app.find_global_settings_argument("--ca-location").should be_nil
    end
  end

  describe "#preinit" do
    before :each do
      app.command_line.stubs(:args).returns %w{}
    end

    describe "parsing the command line" do
      context "with just an action" do
        before :all do
          # We have to stub Signal.trap to avoid a crazy mess where we take
          # over signal handling and make it impossible to cancel the test
          # suite run.
          #
          # It would be nice to fix this elsewhere, but it is actually hard to
          # capture this in rspec 2.5 and all. :(  --daniel 2011-04-08
          Signal.stubs(:trap)
          app.command_line.stubs(:args).returns %w{foo}
          app.preinit
        end

        it "should set the faces based on the type" do
          app.face.name.should == :basetest
        end

        it "should set the format based on the faces default" do
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
        app.face.should_not be_option :bar
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

      it "should not skip when --foo=bar is given" do
        app.command_line.stubs(:args).returns %w{--mandatory=bar --bar foo}
        expect { app.preinit }.
          should raise_error ArgumentError, /Unknown option "--bar"/
      end

      { "boolean options before" => %w{--trace foo},
        "boolean options after"  => %w{foo --trace}
      }.each do |name, args|
        it "should accept global boolean settings #{name} the action" do
          app.command_line.stubs(:args).returns args
          app.preinit && app.parse_options
          Puppet[:trace].should be_true
        end
      end

      { "before" => %w{--syslogfacility user1 foo},
        " after" => %w{foo --syslogfacility user1}
      }.each do |name, args|
        it "should accept global settings with arguments #{name} the action" do
          app.command_line.stubs(:args).returns args
          app.preinit && app.parse_options
          Puppet[:syslogfacility].should == "user1"
        end
      end
    end
  end

  describe "#setup" do
    it "should remove the action name from the arguments" do
      app.command_line.stubs(:args).returns %w{--mandatory --bar foo}
      app.preinit and app.parse_options and app.setup
      app.arguments.should == [{ :mandatory => "--bar" }]
    end

    it "should pass positional arguments" do
      app.command_line.stubs(:args).returns %w{--mandatory --bar foo bar baz quux}
      app.preinit and app.parse_options and app.setup
      app.arguments.should == ['bar', 'baz', 'quux', { :mandatory => "--bar" }]
    end
  end

  describe "#main" do
    before do
      app.face      = Puppet::Faces[:basetest, '0.0.1']
      app.action    = app.face.get_action(:foo)
      app.format    = :pson
      app.arguments = ["myname", "myarg"]
    end

    it "should send the specified verb and name to the faces" do
      app.face.expects(:foo).with(*app.arguments)
      app.main
    end

    it "should use its render method to render any result" do
      app.expects(:render).with(app.arguments.length + 1)
      app.main
    end
  end
end
