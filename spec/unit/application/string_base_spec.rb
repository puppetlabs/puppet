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

  before do
    @app = Puppet::Application::StringBase::Basetest.new
    @app.stubs(:exit)
    @app.stubs(:puts)
    Puppet::Util::Log.stubs(:newdestination)
  end

  describe "when calling main" do
    before do
      @app.verb = :find
      @app.arguments = ["myname", "myarg"]
      @app.string.stubs(:find)
    end

    it "should send the specified verb and name to the string" do
      @app.string.expects(:find).with("myname", "myarg")

      @app.main
    end

    it "should use its render method to render any result"

    it "should exit with the current exit code"
  end

  describe "during setup" do
    before do
      @app.command_line.stubs(:args).returns(["find", "myname", "myarg"])
      @app.stubs(:validate)
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
