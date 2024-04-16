require 'spec_helper'
require 'puppet/util/command_line/puppet_option_parser'

describe Puppet::Util::CommandLine::PuppetOptionParser do
  let(:option_parser) { described_class.new }

  describe "an option with a value" do
    it "parses a 'long' option with a value" do
      parses(
        :option => ["--angry", "Angry", :REQUIRED],
        :from_arguments => ["--angry", "foo"],
        :expects => "foo"
      )
      expect(@logs).to be_empty
    end

    it "parses a 'long' option with a value and converts '-' to '_' & warns" do
      parses(
        :option => ["--an_gry", "Angry", :REQUIRED],
        :from_arguments => ["--an-gry", "foo"],
        :expects => "foo"
      )
      expect(@logs).to have_matching_log(/Partial argument match detected: correct argument is --an_gry, got --an-gry. Partial argument matching is deprecated and will be removed in a future release./)
    end

    it "parses a 'long' option with a value and converts '_' to '-' & warns" do
      parses(
        :option => ["--an-gry", "Angry", :REQUIRED],
        :from_arguments => ["--an_gry", "foo"],
        :expects => "foo"
      )
      expect(@logs).to have_matching_log(/Partial argument match detected: correct argument is --an-gry, got --an_gry. Partial argument matching is deprecated and will be removed in a future release./)
    end

    it "parses a 'short' option with a value" do
      parses(
        :option => ["--angry", "-a", "Angry", :REQUIRED],
        :from_arguments => ["-a", "foo"],
        :expects => "foo"
      )
      expect(@logs).to be_empty
    end

    it "overrides a previous argument with a later one" do
      parses(
        :option => ["--later", "Later", :REQUIRED],
        :from_arguments => ["--later", "tomorrow", "--later", "morgen"],
        :expects => "morgen"
      )
      expect(@logs).to be_empty
    end
  end

  describe "an option without a value" do
    it "parses a 'long' option" do
      parses(
        :option => ["--angry", "Angry", :NONE],
        :from_arguments => ["--angry"],
        :expects => true
      )
    end

    it "converts '_' to '-' with a 'long' option & warns" do
      parses(
        :option => ["--an-gry", "Angry", :NONE],
        :from_arguments => ["--an_gry"],
        :expects => true
      )
      expect(@logs).to have_matching_log(/Partial argument match detected: correct argument is --an-gry, got --an_gry. Partial argument matching is deprecated and will be removed in a future release./)
    end

    it "converts '-' to '_' with a 'long' option & warns" do
      parses(
        :option => ["--an_gry", "Angry", :NONE],
        :from_arguments => ["--an-gry"],
        :expects => true
      )
      expect(@logs).to have_matching_log(/Partial argument match detected: correct argument is --an_gry, got --an-gry. Partial argument matching is deprecated and will be removed in a future release./)
    end

    it "parses a 'short' option" do
      parses(
        :option => ["--angry", "-a", "Angry", :NONE],
        :from_arguments => ["-a"],
        :expects => true
      )
    end

    it "supports the '--no-blah' syntax" do
      parses(
        :option => ["--[no-]rage", "Rage", :NONE],
        :from_arguments => ["--no-rage"],
        :expects => false
      )
      expect(@logs).to be_empty
    end

    it "resolves '-' to '_' with '--no-blah' syntax" do
      parses(
        :option => ["--[no-]an_gry", "Angry", :NONE],
        :from_arguments => ["--no-an-gry"],
        :expects => false
      )
      expect(@logs).to have_matching_log(/Partial argument match detected: correct argument is --\[no-\]an_gry, got --no-an-gry. Partial argument matching is deprecated and will be removed in a future release./)
    end

    it "resolves '_' to '-' with '--no-blah' syntax" do
      parses(
        :option => ["--[no-]an-gry", "Angry", :NONE],
        :from_arguments => ["--no-an_gry"],
        :expects => false
      )
      expect(@logs).to have_matching_log(/Partial argument match detected: correct argument is --\[no-\]an-gry, got --no-an_gry. Partial argument matching is deprecated and will be removed in a future release./)
    end

    it "resolves '-' to '_' & warns when option is defined with '--no-blah syntax' but argument is given in '--option' syntax" do
      parses(
        :option => ["--[no-]rag-e", "Rage", :NONE],
        :from_arguments => ["--rag_e"],
        :expects => true
      )
      expect(@logs).to have_matching_log(/Partial argument match detected: correct argument is --\[no-\]rag-e, got --rag_e. Partial argument matching is deprecated and will be removed in a future release./)
  end

  it "resolves '_' to '-' & warns when option is defined with '--no-blah syntax' but argument is given in '--option' syntax" do
    parses(
      :option => ["--[no-]rag_e", "Rage", :NONE],
      :from_arguments => ["--rag-e"],
      :expects => true
    )
    expect(@logs).to have_matching_log(/Partial argument match detected: correct argument is --\[no-\]rag_e, got --rag-e. Partial argument matching is deprecated and will be removed in a future release./)
  end

    it "overrides a previous argument with a later one" do
      parses(
        :option => ["--[no-]rage", "Rage", :NONE],
        :from_arguments => ["--rage", "--no-rage"],
        :expects => false
      )
      expect(@logs).to be_empty
    end
  end

  it "does not accept an unknown option specification" do
    expect {
      option_parser.on("not", "enough")
    }.to raise_error(ArgumentError, /this method only takes 3 or 4 arguments/)
  end

  it "does not modify the original argument array" do
    option_parser.on("--foo", "Foo", :NONE) { |val| }
    args = ["--foo"]

    option_parser.parse(args)

    expect(args.length).to eq(1)
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
  it "does not try to expand short options that weren't explicitly registered" do

    [
     ["--ridiculous", "This is ridiculous", :REQUIRED],
     ["--rage-inducing", "This is rage-inducing", :REQUIRED]
    ].each do |option|
      option_parser.on(*option) {}
    end

    expect { option_parser.parse(["-r"]) }.to raise_error(Puppet::Util::CommandLine::PuppetOptionError)
  end

  it "respects :ignore_invalid_options" do
    option_parser.ignore_invalid_options = true
    expect { option_parser.parse(["--unknown-option"]) }.not_to raise_error
  end

  it "raises if there is an invalid option and :ignore_invalid_options is not set" do
    expect { option_parser.parse(["--unknown-option"]) }.to raise_error(Puppet::Util::CommandLine::PuppetOptionError)
  end

  def parses(option_case)
    option = option_case[:option]
    expected_value = option_case[:expects]
    arguments = option_case[:from_arguments]

    seen_value = nil
    option_parser.on(*option) do |val|
      seen_value = val
    end

    option_parser.parse(arguments)

    expect(seen_value).to eq(expected_value)
  end
end
