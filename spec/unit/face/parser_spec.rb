require 'spec_helper'
require 'puppet_spec/files'

require 'puppet/face'

describe Puppet::Face[:parser, :current] do
  include PuppetSpec::Files

  let(:parser) { Puppet::Face[:parser, :current] }

  context "from an interactive terminal" do
    before :each do
      from_an_interactive_terminal
    end

    it "validates the configured site manifest when no files are given" do
      manifest = file_containing('site.pp', "{ invalid =>")

      configured_environment = Puppet::Node::Environment.create(:default, [], manifest)
      Puppet.override(:current_environment => configured_environment) do
        expect { parser.validate() }.to exit_with(1)
      end
    end

    it "validates the given file" do
      manifest = file_containing('site.pp', "{ invalid =>")

      expect { parser.validate(manifest) }.to exit_with(1)
    end

    it "runs error free when there are no validation errors" do
      manifest = file_containing('site.pp', "notify { valid: }")

      parser.validate(manifest)
    end

    it "reports missing files" do
      expect do
        parser.validate("missing.pp")
      end.to raise_error(Puppet::Error, /One or more file\(s\) specified did not exist.*missing\.pp/m)
    end

    it "parses supplied manifest files in the context of a directory environment" do
      manifest = file_containing('test.pp', "{ invalid =>")

      env_loader = Puppet::Environments::Static.new(
        Puppet::Node::Environment.create(:special, [])
      )
      Puppet.override(:environments => env_loader) do
        Puppet[:environment] = 'special'
        expect { parser.validate(manifest) }.to exit_with(1)
      end

      expect(@logs.join).to match(/environment special.*Syntax error at '\{'/)
    end

  end

  it "validates the contents of STDIN when no files given and STDIN is not a tty" do
    from_a_piped_input_of("{ invalid =>")

    expect { parser.validate() }.to exit_with(1)
  end

  def from_an_interactive_terminal
    STDIN.stubs(:tty?).returns(true)
  end

  def from_a_piped_input_of(contents)
    STDIN.stubs(:tty?).returns(false)
    STDIN.stubs(:read).returns(contents)
  end
end
