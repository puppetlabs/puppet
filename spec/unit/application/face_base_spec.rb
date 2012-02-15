#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/application/face_base'
require 'tmpdir'

class Puppet::Application::FaceBase::Basetest < Puppet::Application::FaceBase
end

describe Puppet::Application::FaceBase do
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

    it "should stop if the first thing found is not an action" do
      app.command_line.stubs(:args).returns %w{banana count_args}
      expect { app.run }.to exit_with 1
      @logs.first.should_not be_nil
      @logs.first.message.should =~ /has no 'banana' action/
    end

    it "should use the default action if not given any arguments" do
      app.command_line.stubs(:args).returns []
      action = stub(:options => [], :render_as => nil)
      Puppet::Face[:basetest, '0.0.1'].expects(:get_default_action).returns(action)
      app.stubs(:main)
      app.run
      app.action.should == action
      app.arguments.should == [ { } ]
    end

    it "should use the default action if not given a valid one" do
      app.command_line.stubs(:args).returns %w{bar}
      action = stub(:options => [], :render_as => nil)
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
      expect { app.run }.to exit_with 1
      @logs.first.message.should =~ /has no 'bar' action./
    end

    [%w{something_I_cannot_do},
     %w{something_I_cannot_do argument}].each do |input|
      it "should report unknown actions nicely" do
        app.command_line.stubs(:args).returns input
        Puppet::Face[:basetest, '0.0.1'].expects(:get_default_action).returns(nil)
        app.stubs(:main)
        expect { app.run }.to exit_with 1
        @logs.first.message.should =~ /has no 'something_I_cannot_do' action/
      end
    end

    [%w{something_I_cannot_do --unknown-option},
     %w{something_I_cannot_do argument --unknown-option}].each do |input|
      it "should report unknown actions even if there are unknown options" do
        app.command_line.stubs(:args).returns input
        Puppet::Face[:basetest, '0.0.1'].expects(:get_default_action).returns(nil)
        app.stubs(:main)
        expect { app.run }.to exit_with 1
        @logs.first.message.should =~ /has no 'something_I_cannot_do' action/
      end
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

    it "should handle application-level options", :'fails_on_ruby_1.9.2' => true do
      app.command_line.stubs(:args).returns %w{--verbose return_true}
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
      app.stubs(:puts)          # don't dump text to screen.

      app.face      = Puppet::Face[:basetest, '0.0.1']
      app.action    = app.face.get_action(:foo)
      app.arguments = ["myname", "myarg"]
    end

    it "should send the specified verb and name to the face" do
      app.face.expects(:foo).with(*app.arguments)
      expect { app.main }.to exit_with 0
    end

    it "should lookup help when it cannot do anything else" do
      app.action = nil
      Puppet::Face[:help, :current].expects(:help).with(:basetest)
      expect { app.main }.to exit_with 1
    end

    it "should use its render method to render any result" do
      app.expects(:render).with(app.arguments.length + 1, ["myname", "myarg"])
      expect { app.main }.to exit_with 0
    end
  end

  describe "error reporting" do
    before :each do
      app.stubs(:puts)          # don't dump text to screen.

      app.render_as = :json
      app.face      = Puppet::Face[:basetest, '0.0.1']
      app.arguments = [{}]      # we always have options in there...
    end

    it "should exit 0 when the action returns true" do
      app.action    = app.face.get_action :return_true
      expect { app.main }.to exit_with 0
    end

    it "should exit 0 when the action returns false" do
      app.action = app.face.get_action :return_false
      expect { app.main }.to exit_with 0
    end

    it "should exit 0 when the action returns nil" do
      app.action = app.face.get_action :return_nil
      expect { app.main }.to exit_with 0
    end

    it "should exit non-0 when the action raises" do
      app.action = app.face.get_action :return_raise
      expect { app.main }.not_to exit_with 0
    end

    it "should use the exit code set by the action" do
      app.action = app.face.get_action :with_specific_exit_code
      expect { app.main }.to exit_with 5
    end
  end

  describe "#render" do
    before :each do
      app.face      = Puppet::Face[:basetest, '0.0.1']
      app.action    = app.face.get_action(:foo)
    end

    context "default rendering" do
      before :each do app.setup end

      ["hello", 1, 1.0].each do |input|
        it "should just return a #{input.class.name}" do
          app.render(input, {}).should == input
        end
      end

      [[1, 2], ["one"], [{ 1 => 1 }]].each do |input|
        it "should render #{input.class} using JSON" do
          app.render(input, {}).should == input.to_pson.chomp
        end
      end

      it "should render a non-trivially-keyed Hash with using JSON" do
        hash = { [1,2] => 3, [2,3] => 5, [3,4] => 7 }
        app.render(hash, {}).should == hash.to_pson.chomp
      end

      it "should render a {String,Numeric}-keyed Hash into a table" do
        object = Object.new
        hash = { "one" => 1, "two" => [], "three" => {}, "four" => object,
          5 => 5, 6.0 => 6 }

        # Gotta love ASCII-betical sort order.  Hope your objects are better
        # structured for display than my test one is. --daniel 2011-04-18
        app.render(hash, {}).should == <<EOT
5      5
6.0    6
four   #{object.to_pson.chomp}
one    1
three  {}
two    []
EOT
      end

      it "should render a hash nicely with a multi-line value" do
        pending "Moving to PSON rather than PP makes this unsupportable."
        hash = {
          "number" => { "1" => '1' * 40, "2" => '2' * 40, '3' => '3' * 40 },
          "text"   => { "a" => 'a' * 40, 'b' => 'b' * 40, 'c' => 'c' * 40 }
        }
        app.render(hash, {}).should == <<EOT
number  {"1"=>"1111111111111111111111111111111111111111",
         "2"=>"2222222222222222222222222222222222222222",
         "3"=>"3333333333333333333333333333333333333333"}
text    {"a"=>"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
         "b"=>"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
         "c"=>"cccccccccccccccccccccccccccccccccccccccc"}
EOT
      end

      describe "when setting the rendering method" do
        after do
          # need to reset the when_rendering block so that other tests can set it later
          app.action.instance_variable_set("@when_rendering", {})
        end

        it "should invoke the action rendering hook while rendering" do
          app.action.set_rendering_method_for(:console, proc { |value| "bi-winning!" })
          app.render("bi-polar?", {}).should == "bi-winning!"
        end

        it "should invoke the action rendering hook with args and options while rendering" do
          app.action.instance_variable_set("@when_rendering", {})
          app.action.when_invoked = proc { |name, options| 'just need to match arity for rendering' }
          app.action.set_rendering_method_for(
            :console,
            proc { |value, name, options| "I'm #{name}, no wait, I'm #{options[:altername]}" }
          )
          app.render("bi-polar?", ['bob', {:altername => 'sue'}]).should == "I'm bob, no wait, I'm sue"
        end
      end

      it "should render JSON when asked for json" do
        app.render_as = :json
        json = app.render({ :one => 1, :two => 2 }, {})
        json.should =~ /"one":\s*1\b/
        json.should =~ /"two":\s*2\b/
        PSON.parse(json).should == { "one" => 1, "two" => 2 }
      end
    end

    it "should fail early if asked to render an invalid format" do
      app.command_line.stubs(:args).returns %w{--render-as interpretive-dance return_true}
      # We shouldn't get here, thanks to the exception, and our expectation on
      # it, but this helps us fail if that slips up and all. --daniel 2011-04-27
      Puppet::Face[:help, :current].expects(:help).never

      expect {
        expect { app.run }.to exit_with 1
      }.to have_printed(/I don't know how to render 'interpretive-dance'/)
    end

    it "should work if asked to render a NetworkHandler format" do
      app.command_line.stubs(:args).returns %w{count_args a b c --render-as yaml}
      expect {
        expect { app.run }.to exit_with 0
      }.to have_printed(/--- 3/)
    end

    it "should invoke when_rendering hook 's' when asked to render-as 's'" do
      app.command_line.stubs(:args).returns %w{with_s_rendering_hook --render-as s}
      app.action = app.face.get_action(:with_s_rendering_hook)
      expect {
        expect { app.run }.to exit_with 0
      }.to have_printed(/you invoked the 's' rendering hook/)
    end
  end
end
