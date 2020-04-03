require 'spec_helper'
require 'puppet/application/face_base'
require 'tmpdir'

class Puppet::Application::FaceBase::Basetest < Puppet::Application::FaceBase
end

describe Puppet::Application::FaceBase do
  let :app do
    app = Puppet::Application::FaceBase::Basetest.new
    allow(app.command_line).to receive(:subcommand_name).and_return('subcommand')
    allow(Puppet::Util::Log).to receive(:newdestination)
    app
  end

  after :each do
    app.class.clear_everything_for_tests
  end

  describe "#find_global_settings_argument" do
    it "should not match --ca to --ca-location" do
      option = double('ca option', :optparse_args => ["--ca"])
      expect(Puppet.settings).to receive(:each).and_yield(:ca, option)

      expect(app.find_global_settings_argument("--ca-location")).to be_nil
    end
  end

  describe "#parse_options" do
    before :each do
      allow(app.command_line).to receive(:args).and_return(%w{})
    end

    describe "with just an action" do
      before(:each) do
        # We have to stub Signal.trap to avoid a crazy mess where we take
        # over signal handling and make it impossible to cancel the test
        # suite run.
        #
        # It would be nice to fix this elsewhere, but it is actually hard to
        # capture this in rspec 2.5 and all. :(  --daniel 2011-04-08
        allow(Signal).to receive(:trap)
        allow(app.command_line).to receive(:args).and_return(%w{foo})
        app.preinit
        app.parse_options
      end

      it "should set the face based on the type" do
        expect(app.face.name).to eq(:basetest)
      end

      it "should find the action" do
        expect(app.action).to be
        expect(app.action.name).to eq(:foo)
      end
    end

    it "should stop if the first thing found is not an action" do
      allow(app.command_line).to receive(:args).and_return(%w{banana count_args})

      expect { app.run }.to exit_with(1)

      expect(@logs.map(&:message)).to eq(["'basetest' has no 'banana' action.  See `puppet help basetest`."])
    end

    it "should use the default action if not given any arguments" do
      allow(app.command_line).to receive(:args).and_return([])
      action = double(:options => [], :render_as => nil)
      expect(Puppet::Face[:basetest, '0.0.1']).to receive(:get_default_action).and_return(action)
      allow(app).to receive(:main)
      app.run
      expect(app.action).to eq(action)
      expect(app.arguments).to eq([ { } ])
    end

    it "should use the default action if not given a valid one" do
      allow(app.command_line).to receive(:args).and_return(%w{bar})
      action = double(:options => [], :render_as => nil)
      expect(Puppet::Face[:basetest, '0.0.1']).to receive(:get_default_action).and_return(action)
      allow(app).to receive(:main)
      app.run
      expect(app.action).to eq(action)
      expect(app.arguments).to eq([ 'bar', { } ])
    end

    it "should have no action if not given a valid one and there is no default action" do
      allow(app.command_line).to receive(:args).and_return(%w{bar})
      expect(Puppet::Face[:basetest, '0.0.1']).to receive(:get_default_action).and_return(nil)
      allow(app).to receive(:main)
      expect { app.run }.to exit_with(1)
      expect(@logs.first.message).to match(/has no 'bar' action./)
    end

    [%w{something_I_cannot_do},
     %w{something_I_cannot_do argument}].each do |input|
      it "should report unknown actions nicely" do
        allow(app.command_line).to receive(:args).and_return(input)
        expect(Puppet::Face[:basetest, '0.0.1']).to receive(:get_default_action).and_return(nil)
        allow(app).to receive(:main)
        expect { app.run }.to exit_with(1)
        expect(@logs.first.message).to match(/has no 'something_I_cannot_do' action/)
      end
    end

    [%w{something_I_cannot_do --unknown-option},
     %w{something_I_cannot_do argument --unknown-option}].each do |input|
      it "should report unknown actions even if there are unknown options" do
        allow(app.command_line).to receive(:args).and_return(input)
        expect(Puppet::Face[:basetest, '0.0.1']).to receive(:get_default_action).and_return(nil)
        allow(app).to receive(:main)
        expect { app.run }.to exit_with(1)
        expect(@logs.first.message).to match(/has no 'something_I_cannot_do' action/)
      end
    end

    it "should report a sensible error when options with = fail" do
      allow(app.command_line).to receive(:args).and_return(%w{--action=bar foo})
      expect { app.preinit; app.parse_options }.
        to raise_error(OptionParser::InvalidOption, /invalid option: --action/)
    end

    it "should fail if an action option is before the action" do
      allow(app.command_line).to receive(:args).and_return(%w{--action foo})
      expect { app.preinit; app.parse_options }.
        to raise_error(OptionParser::InvalidOption, /invalid option: --action/)
    end

    it "should fail if an unknown option is before the action" do
      allow(app.command_line).to receive(:args).and_return(%w{--bar foo})
      expect { app.preinit; app.parse_options }.
        to raise_error(OptionParser::InvalidOption, /invalid option: --bar/)
    end

    it "should fail if an unknown option is after the action" do
      allow(app.command_line).to receive(:args).and_return(%w{foo --bar})
      expect { app.preinit; app.parse_options }.
        to raise_error(OptionParser::InvalidOption, /invalid option: --bar/)
    end

    it "should accept --bar as an argument to a mandatory option after action" do
      allow(app.command_line).to receive(:args).and_return(%w{foo --mandatory --bar})
      app.preinit
      app.parse_options
      expect(app.action.name).to eq(:foo)
      expect(app.options).to eq({ :mandatory => "--bar" })
    end

    it "should accept --bar as an argument to a mandatory option before action" do
      allow(app.command_line).to receive(:args).and_return(%w{--mandatory --bar foo})
      app.preinit
      app.parse_options
      expect(app.action.name).to eq(:foo)
      expect(app.options).to eq({ :mandatory => "--bar" })
    end

    it "should not skip when --foo=bar is given" do
      allow(app.command_line).to receive(:args).and_return(%w{--mandatory=bar --bar foo})
      expect { app.preinit; app.parse_options }.
        to raise_error(OptionParser::InvalidOption, /invalid option: --bar/)
    end

    it "does not skip when a puppet global setting is given as one item" do
      allow(app.command_line).to receive(:args).and_return(%w{--confdir=/tmp/puppet foo})
      app.preinit
      app.parse_options
      expect(app.action.name).to eq(:foo)
      expect(app.options).to eq({})
    end

    it "does not skip when a puppet global setting is given as two items" do
      allow(app.command_line).to receive(:args).and_return(%w{--confdir /tmp/puppet foo})
      app.preinit
      app.parse_options
      expect(app.action.name).to eq(:foo)
      expect(app.options).to eq({})
    end

    it "should not add :debug to the application-level options" do
      allow(app.command_line).to receive(:args).and_return(%w{--confdir /tmp/puppet foo --debug})
      app.preinit
      app.parse_options
      expect(app.action.name).to eq(:foo)
      expect(app.options).to eq({})
    end

    it "should not add :verbose to the application-level options" do
      allow(app.command_line).to receive(:args).and_return(%w{--confdir /tmp/puppet foo --verbose})
      app.preinit
      app.parse_options
      expect(app.action.name).to eq(:foo)
      expect(app.options).to eq({})
    end

    { "boolean options before" => %w{--trace foo},
      "boolean options after"  => %w{foo --trace}
    }.each do |name, args|
      it "should accept global boolean settings #{name} the action" do
        allow(app.command_line).to receive(:args).and_return(args)
        Puppet.settings.initialize_global_settings(args)
        app.preinit
        app.parse_options
        expect(Puppet[:trace]).to be_truthy
      end
    end

    { "before" => %w{--syslogfacility user1 foo},
      " after" => %w{foo --syslogfacility user1}
    }.each do |name, args|
      it "should accept global settings with arguments #{name} the action" do
        allow(app.command_line).to receive(:args).and_return(args)
        Puppet.settings.initialize_global_settings(args)
        app.preinit
        app.parse_options
        expect(Puppet[:syslogfacility]).to eq("user1")
      end
    end

    it "should handle application-level options" do
      allow(app.command_line).to receive(:args).and_return(%w{--verbose return_true})
      app.preinit
      app.parse_options
      expect(app.face.name).to eq(:basetest)
    end
  end

  describe "#setup" do
    it "should remove the action name from the arguments" do
      allow(app.command_line).to receive(:args).and_return(%w{--mandatory --bar foo})
      app.preinit
      app.parse_options
      app.setup
      expect(app.arguments).to eq([{ :mandatory => "--bar" }])
    end

    it "should pass positional arguments" do
      myargs = %w{--mandatory --bar foo bar baz quux}
      allow(app.command_line).to receive(:args).and_return(myargs)
      app.preinit
      app.parse_options
      app.setup
      expect(app.arguments).to eq(['bar', 'baz', 'quux', { :mandatory => "--bar" }])
    end
  end

  describe "#main" do
    before :each do
      allow(app).to receive(:puts)          # don't dump text to screen.

      app.face      = Puppet::Face[:basetest, '0.0.1']
      app.action    = app.face.get_action(:foo)
      app.arguments = ["myname", "myarg"]
    end

    it "should send the specified verb and name to the face" do
      expect(app.face).to receive(:foo).with(*app.arguments)
      expect { app.main }.to exit_with(0)
    end

    it "should lookup help when it cannot do anything else" do
      app.action = nil
      expect(Puppet::Face[:help, :current]).to receive(:help).with(:basetest)
      expect { app.main }.to exit_with(1)
    end

    it "should use its render method to render any result" do
      expect(app).to receive(:render).with(app.arguments.length + 1, ["myname", "myarg"])
      expect { app.main }.to exit_with(0)
    end

    it "should issue a deprecation warning if the face is deprecated" do
      # since app is shared across examples, stub to avoid affecting shared context
      allow(app.face).to receive(:deprecated?).and_return(true)
      expect(app.face).to receive(:foo).with(*app.arguments)
      expect(Puppet).to receive(:deprecation_warning).with(/'puppet basetest' is deprecated/)
      expect { app.main }.to exit_with(0)
    end

    it "should not issue a deprecation warning if the face is not deprecated" do
      expect(Puppet).not_to receive(:deprecation_warning)
      # since app is shared across examples, stub to avoid affecting shared context
      allow(app.face).to receive(:deprecated?).and_return(false)
      expect(app.face).to receive(:foo).with(*app.arguments)
      expect { app.main }.to exit_with(0)
    end
  end

  describe "error reporting" do
    before :each do
      allow(app).to receive(:puts)          # don't dump text to screen.

      app.render_as = :json
      app.face      = Puppet::Face[:basetest, '0.0.1']
      app.arguments = [{}]      # we always have options in there...
    end

    it "should exit 0 when the action returns true" do
      app.action    = app.face.get_action :return_true
      expect { app.main }.to exit_with(0)
    end

    it "should exit 0 when the action returns false" do
      app.action = app.face.get_action :return_false
      expect { app.main }.to exit_with(0)
    end

    it "should exit 0 when the action returns nil" do
      app.action = app.face.get_action :return_nil
      expect { app.main }.to exit_with(0)
    end

    it "should exit non-0 when the action raises" do
      app.action = app.face.get_action :return_raise
      expect { app.main }.not_to exit_with(0)
    end

    it "should use the exit code set by the action" do
      app.action = app.face.get_action :with_specific_exit_code
      expect { app.main }.to exit_with(5)
    end
  end

  describe "#render" do
    before :each do
      app.face      = Puppet::Interface.new('basetest', '0.0.1')
      app.action    = Puppet::Interface::Action.new(app.face, :foo)
    end

    context "default rendering" do
      before :each do app.setup end

      ["hello", 1, 1.0].each do |input|
        it "should just return a #{input.class.name}" do
          expect(app.render(input, {})).to eq(input)
        end
      end

      [[1, 2], ["one"], [{ 1 => 1 }]].each do |input|
        it "should render Array as one item per line" do
          expect(app.render(input, {})).to eq(input.collect { |item| item.to_s + "\n" }.join(''))
        end
      end

      it "should render a non-trivially-keyed Hash with using pretty printed JSON" do
        hash = { [1,2] => 3, [2,3] => 5, [3,4] => 7 }
        expect(app.render(hash, {})).to eq(Puppet::Util::Json.dump(hash, :pretty => true).chomp)
      end

      it "should render a {String,Numeric}-keyed Hash into a table" do
        object = Object.new
        hash = { "one" => 1, "two" => [], "three" => {}, "four" => object,
          5 => 5, 6.0 => 6 }

        # Gotta love ASCII-betical sort order.  Hope your objects are better
        # structured for display than my test one is. --daniel 2011-04-18
        expect(app.render(hash, {})).to eq <<EOT
5      5
6.0    6
four   #{Puppet::Util::Json.dump(object).chomp}
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
        expect(app.render(hash, {})).to eq <<EOT
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
          expect(app.render("bi-polar?", {})).to eq("bi-winning!")
        end

        it "should invoke the action rendering hook with args and options while rendering" do
          app.action.instance_variable_set("@when_rendering", {})
          app.action.when_invoked = proc { |name, options| 'just need to match arity for rendering' }
          app.action.set_rendering_method_for(
            :console,
            proc { |value, name, options| "I'm #{name}, no wait, I'm #{options[:altername]}" }
          )
          expect(app.render("bi-polar?", ['bob', {:altername => 'sue'}])).to eq("I'm bob, no wait, I'm sue")
        end
      end

      it "should render JSON when asked for json" do
        app.render_as = :json
        json = app.render({ :one => 1, :two => 2 }, {})
        expect(json).to match(/"one":\s*1\b/)
        expect(json).to match(/"two":\s*2\b/)
        expect(JSON.parse(json)).to eq({ "one" => 1, "two" => 2 })
      end
    end

    it "should fail early if asked to render an invalid format" do
      allow(app.command_line).to receive(:args).and_return(%w{--render-as interpretive-dance return_true})
      # We shouldn't get here, thanks to the exception, and our expectation on
      # it, but this helps us fail if that slips up and all. --daniel 2011-04-27
      expect(Puppet::Face[:help, :current]).not_to receive(:help)

      expect(Puppet).to receive(:send_log).with(:err, "Could not parse application options: I don't know how to render 'interpretive-dance'")

      expect { app.run }.to exit_with(1)
    end

    it "should work if asked to render json" do
      allow(app.command_line).to receive(:args).and_return(%w{count_args a b c --render-as json})
      expect {
        app.run
      }.to exit_with(0)
       .and have_printed(/3/)
    end

    it "should invoke when_rendering hook 's' when asked to render-as 's'" do
      allow(app.command_line).to receive(:args).and_return(%w{with_s_rendering_hook --render-as s})
      app.action = app.face.get_action(:with_s_rendering_hook)
      expect {
        app.run
      }.to exit_with(0)
       .and have_printed(/you invoked the 's' rendering hook/)
    end
  end

  describe "#help" do
    it "should generate help for --help" do
      allow(app.command_line).to receive(:args).and_return(%w{--help})
      expect(Puppet::Face[:help, :current]).to receive(:help)
      expect { app.run }.to exit_with(0)
    end

    it "should generate help for -h" do
      allow(app.command_line).to receive(:args).and_return(%w{-h})
      expect(Puppet::Face[:help, :current]).to receive(:help)
      expect { app.run }.to exit_with(0)
    end
  end
end
