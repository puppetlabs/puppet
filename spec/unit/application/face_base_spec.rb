#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/application/face_base'
require 'tmpdir'

class Puppet::Application::FaceBase::Basetest < Puppet::Application::FaceBase
end

describe Puppet::Application::FaceBase do
  before :all do
    Puppet::Face.define(:basetest, '0.0.1') do
      option("--[no-]boolean")
      option("--mandatory MANDATORY")

      action :foo do
        option("--action")
        when_invoked { |*args| args.length }
      end
    end
  end

  let :app do
    app = Puppet::Application::FaceBase::Basetest.new
    app.command_line.stubs(:subcommand_name).returns('subcommand')
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

  describe "#parse_options" do
    before :each do
      app.command_line.stubs(:args).returns %w{}
    end

    describe "with just an action" do
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
        app.parse_options
      end

      it "should set the face based on the type" do
        app.face.name.should == :basetest
      end

      it "should find the action" do
        app.action.should be
        app.action.name.should == :foo
      end
    end

    it "should use the default action if not given any arguments" do
      app.command_line.stubs(:args).returns []
      action = stub(:options => [])
      Puppet::Face[:basetest, '0.0.1'].expects(:get_default_action).returns(action)
      app.stubs(:main)
      app.run
      app.action.should == action
      app.arguments.should == [ { } ]
    end

    it "should use the default action if not given a valid one" do
      app.command_line.stubs(:args).returns %w{bar}
      action = stub(:options => [])
      Puppet::Face[:basetest, '0.0.1'].expects(:get_default_action).returns(action)
      app.stubs(:main)
      app.run
      app.action.should == action
      app.arguments.should == [ 'bar', { } ]
    end

    it "should have no action if not given a valid one and there is no default action" do
      app.command_line.stubs(:args).returns %w{bar}
      Puppet::Face[:basetest, '0.0.1'].expects(:get_default_action).returns(nil)
      app.stubs(:main)
      app.run
      app.action.should be_nil
      app.arguments.should == [ 'bar', { } ]
    end

    it "should report a sensible error when options with = fail" do
      app.command_line.stubs(:args).returns %w{--action=bar foo}
      expect { app.preinit; app.parse_options }.
        to raise_error OptionParser::InvalidOption, /invalid option: --action/
    end

    it "should fail if an action option is before the action" do
      app.command_line.stubs(:args).returns %w{--action foo}
      expect { app.preinit; app.parse_options }.
        to raise_error OptionParser::InvalidOption, /invalid option: --action/
    end

    it "should fail if an unknown option is before the action" do
      app.command_line.stubs(:args).returns %w{--bar foo}
      expect { app.preinit; app.parse_options }.
        to raise_error OptionParser::InvalidOption, /invalid option: --bar/
    end

    it "should fail if an unknown option is after the action" do
      app.command_line.stubs(:args).returns %w{foo --bar}
      expect { app.preinit; app.parse_options }.
        to raise_error OptionParser::InvalidOption, /invalid option: --bar/
    end

    it "should accept --bar as an argument to a mandatory option after action" do
      app.command_line.stubs(:args).returns %w{foo --mandatory --bar}
      app.preinit
      app.parse_options
      app.action.name.should == :foo
      app.options.should == { :mandatory => "--bar" }
    end

    it "should accept --bar as an argument to a mandatory option before action" do
      app.command_line.stubs(:args).returns %w{--mandatory --bar foo}
      app.preinit
      app.parse_options
      app.action.name.should == :foo
      app.options.should == { :mandatory => "--bar" }
    end

    it "should not skip when --foo=bar is given" do
      app.command_line.stubs(:args).returns %w{--mandatory=bar --bar foo}
      expect { app.preinit; app.parse_options }.
        to raise_error OptionParser::InvalidOption, /invalid option: --bar/
    end

    { "boolean options before" => %w{--trace foo},
      "boolean options after"  => %w{foo --trace}
    }.each do |name, args|
      it "should accept global boolean settings #{name} the action" do
        app.command_line.stubs(:args).returns args
        app.preinit
        app.parse_options
        Puppet[:trace].should be_true
      end
    end

    { "before" => %w{--syslogfacility user1 foo},
      " after" => %w{foo --syslogfacility user1}
    }.each do |name, args|
      it "should accept global settings with arguments #{name} the action" do
        app.command_line.stubs(:args).returns args
        app.preinit
        app.parse_options
        Puppet[:syslogfacility].should == "user1"
      end
    end

    it "should handle application-level options" do
      app.command_line.stubs(:args).returns %w{help --verbose help}
      app.preinit
      app.parse_options
      app.face.name.should == :basetest
    end
  end

  describe "#setup" do
    it "should remove the action name from the arguments" do
      app.command_line.stubs(:args).returns %w{--mandatory --bar foo}
      app.preinit
      app.parse_options
      app.setup
      app.arguments.should == [{ :mandatory => "--bar" }]
    end

    it "should pass positional arguments" do
      app.command_line.stubs(:args).returns %w{--mandatory --bar foo bar baz quux}
      app.preinit
      app.parse_options
      app.setup
      app.arguments.should == ['bar', 'baz', 'quux', { :mandatory => "--bar" }]
    end
  end

  describe "#main" do
    before :each do
      app.expects(:exit).with(0)

      app.face      = Puppet::Face[:basetest, '0.0.1']
      app.action    = app.face.get_action(:foo)
      app.arguments = ["myname", "myarg"]
    end

    it "should send the specified verb and name to the face" do
      app.face.expects(:foo).with(*app.arguments)
      app.main
    end

    it "should lookup help when it cannot do anything else" do
      app.action = nil
      Puppet::Face[:help, :current].expects(:help).with(:basetest, *app.arguments)
      app.stubs(:puts)          # meh.  Don't print nil, thanks. --daniel 2011-04-12
      app.main
    end

    it "should use its render method to render any result" do
      app.expects(:render).with(app.arguments.length + 1)
      app.stubs(:puts)          # meh.  Don't print nil, thanks. --daniel 2011-04-12
      app.main
    end
  end

  describe "#render" do
    before :each do
      app.face   = Puppet::Face[:basetest, '0.0.1']
      app.action = app.face.get_action(:foo)
    end

    ["hello", 1, 1.0].each do |input|
      it "should just return a #{input.class.name}" do
        app.render(input).should == input
      end
    end

    [[1, 2], ["one"], [{ 1 => 1 }]].each do |input|
      it "should render #{input.class} using the 'pp' library" do
        app.render(input).should == input.pretty_inspect
      end
    end

    it "should render a non-trivially-keyed Hash with the 'pp' library" do
      hash = { [1,2] => 3, [2,3] => 5, [3,4] => 7 }
      app.render(hash).should == hash.pretty_inspect
    end

    it "should render a {String,Numeric}-keyed Hash into a table" do
      object = Object.new
      hash = { "one" => 1, "two" => [], "three" => {}, "four" => object,
        5 => 5, 6.0 => 6 }

      # Gotta love ASCII-betical sort order.  Hope your objects are better
      # structured for display than my test one is. --daniel 2011-04-18
      app.render(hash).should == <<EOT
5      5
6.0    6
four   #{object.pretty_inspect.chomp}
one    1
three  {}
two    []
EOT
    end

    it "should render a hash nicely with a multi-line value" do
      hash = {
        "number" => { "1" => '1' * 40, "2" => '2' * 40, '3' => '3' * 40 },
        "text"   => { "a" => 'a' * 40, 'b' => 'b' * 40, 'c' => 'c' * 40 }
      }
      app.render(hash).should == <<EOT
number  {"1"=>"1111111111111111111111111111111111111111",
         "2"=>"2222222222222222222222222222222222222222",
         "3"=>"3333333333333333333333333333333333333333"}
text    {"a"=>"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
         "b"=>"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
         "c"=>"cccccccccccccccccccccccccccccccccccccccc"}
EOT
    end

    it "should invoke the action rendering hook while rendering" do
      app.action.set_rendering_method_for(:for_humans, proc { |value| "bi-winning!" })
      app.action.render_as = :for_humans
      app.render("bi-polar?").should == "bi-winning!"
    end
  end
end
