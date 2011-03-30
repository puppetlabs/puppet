#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'puppet/application/string_base'
require 'tmpdir'

class Puppet::Application::StringBase::Basetest < Puppet::Application::StringBase
  option("--[no-]foo")
end

describe Puppet::Application::StringBase do
  before :all do
    @dir = Dir.mktmpdir
    $LOAD_PATH.push(@dir)
    FileUtils.mkdir_p(File.join @dir, 'puppet', 'string')
    File.open(File.join(@dir, 'puppet', 'string', 'basetest.rb'), 'w') do |f|
      f.puts "Puppet::String.define(:basetest, '0.0.1')"
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
    app.command_line.stubs(:args).returns []
    Puppet::Util::Log.stubs(:newdestination)
    app
  end

  describe "#preinit" do
    before :each do
      app.command_line.stubs(:args).returns %w{}
    end

    it "should set the string based on the type"
    it "should set the format based on the string default"

    describe "parsing the command line" do
      before :all do
        Puppet::String[:basetest, '0.0.1'].action :foo do
          option "--foo"
          invoke do |options|
            options
          end
        end
      end

      it "should find the action" do
        app.command_line.stubs(:args).returns %w{foo}
        app.preinit
        app.action.should be
        app.action.name.should == :foo
      end

      it "should fail if no action is given" do
        expect { app.preinit }.
          should raise_error ArgumentError, /No action given/
      end

      it "should report a sensible error when options with = fail" do
        app.command_line.stubs(:args).returns %w{--foo=bar foo}
        expect { app.preinit }.
          should raise_error ArgumentError, /Unknown option "--foo"/
      end

      it "should fail if an action option is before the action" do
        app.command_line.stubs(:args).returns %w{--foo foo}
        expect { app.preinit }.
          should raise_error ArgumentError, /Unknown option "--foo"/
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
    end
  end

  describe "when calling main" do
    before do
      @app.verb = :find
      @app.arguments = ["myname", "myarg"]
      @app.string.stubs(:find)
    end

    it "should send the specified verb and name to the string" do
      @app.string.expects(:find).with("myname", "myarg")
      app.main
    end

    it "should use its render method to render any result"

    it "should exit with the current exit code"
  end

  describe "during setup" do
    before do
      app.command_line.stubs(:args).returns(["find", "myname", "myarg"])
      app.stubs(:validate)
    end

    it "should set the verb from the command line arguments" do
      @app.setup
      @app.verb.should == "find"
    end

    it "should make sure arguments are an array" do
      @app.command_line.stubs(:args).returns(["find", "myname", "myarg"])
      @app.setup
      @app.arguments.should == ["myname", "myarg", {}]
    end

    it "should pass options as the last argument" do
      @app.command_line.stubs(:args).returns(["find", "myname", "myarg", "--foo"])
      @app.parse_options
      @app.setup
      @app.arguments.should == ["myname", "myarg", { :foo => true }]
    end
  end
end
