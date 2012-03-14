require 'spec_helper'
require 'puppet/util/command_line_utils/puppet_option_parser'

module Puppet::Util::CommandLineUtils
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




    # TODO cprice: explain this insanity
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
