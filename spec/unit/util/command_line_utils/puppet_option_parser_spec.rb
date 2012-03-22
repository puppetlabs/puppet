require 'spec_helper'
require 'puppet/util/command_line/puppet_option_parser'

class Puppet::Util::CommandLine
  describe PuppetOptionParser do
    let(:option_parser) { PuppetOptionParser.new }


    it "should trigger callback for a 'long' option with a value" do
      self.expects(:handle_option).with("--angry", "foo")
      option_parser.on(*["--angry", "Angry", :REQUIRED]) do |val|
        handle_option("--angry", val)
      end
      expect { option_parser.parse(["--angry", "foo"]) }.not_to raise_error
    end

    it "should trigger callback for a 'short' option with a value" do
      self.expects(:handle_option).with("--angry", "foo")
      option_parser.on(*["--angry", "-a", "Angry", :REQUIRED]) do |val|
        handle_option("--angry", val)
      end
      expect { option_parser.parse(["-a", "foo"]) }.not_to raise_error
    end

    it "should trigger callback for a 'long' option without a value" do
      self.expects(:handle_option).with("--angry", true)
      option_parser.on(*["--angry", "Angry", :NONE]) do |val|
        handle_option("--angry", val)
      end
      expect { option_parser.parse(["--angry"]) }.not_to raise_error
    end

    it "should trigger callback for a 'short' option without a value" do
      self.expects(:handle_option).with("--angry", true)
      option_parser.on(*["--angry", "-a", "Angry", :NONE]) do |val|
        handle_option("--angry", val)
      end
      expect { option_parser.parse(["-a"]) }.not_to raise_error
    end

    it "should support the '--no-blah' syntax" do
      self.expects(:handle_option).with("--rage", false)
      option_parser.on(*["--[no-]rage", "Rage", :NONE]) do |val|
        handle_option("--rage", val)
      end
      expect { option_parser.parse(["--no-rage"]) }.not_to raise_error
    end

    describe "#parse" do
      it "should not modify the original argument array" do
        self.expects(:handle_option).with("--foo", true)
        option_parser.on(*["--foo", "Foo", :NONE]) do |val|
           handle_option("--foo", val)
        end
        args = ["--foo"]
        expect { option_parser.parse(args) }.not_to raise_error
        args.length.should == 1
      end
    end




    # The ruby stdlib OptionParser has an awesome "feature" that you cannot disable, whereby if
    #  it sees a short option that you haven't specifically registered with it (e.g., "-r"), it
    #  will automatically attempt to expand it out to whatever long options that you might have
    #  registered.  Since we need to do our option parsing in two passes (one pass against only
    #  the global/puppet-wide settings definitions, and then a second pass that includes the
    #  application or face settings--because we can't load the app/face until we've determined
    #  the libdir), it is entirely possible that we intend to define our "short" option as part
    #  of the second pass.  Therefore, if the option parser attempts to expand it out into a
    #  long option during the first pass, terrible things will happen.
    #
    # A long story short: we need to have the ability to control this kind of behavior in our
    #  option parser, and this test simply affirms that we do.
    it "should not try to expand short options that weren't explicitly registered" do

      [
       ["--ridiculous", "This is ridiculous", :REQUIRED],
       ["--rage-inducing", "This is rage-inducing", :REQUIRED]
      ].each do |option|
        option_parser.on(*option) {}
      end

      expect { option_parser.parse(["-r"]) }.to raise_error(PuppetUnrecognizedOptionError)
    end

    it "should respect :ignore_invalid_options" do
      option_parser.ignore_invalid_options = true
      expect { option_parser.parse(["--foo"]) }.not_to raise_error
    end

    it "should raise if there is an invalid option and :ignore_invalid_options is not set" do
      expect { option_parser.parse(["--foo"]) }.to raise_error(PuppetOptionError)
    end


  end
end
