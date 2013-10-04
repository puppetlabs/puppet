require 'spec_helper'
require 'puppet_spec/files'

require 'puppet/face'

describe Puppet::Face[:parser, :current] do
  include PuppetSpec::Files

  let(:parser) { Puppet::Face[:parser, :current] }

  it "validates the configured site manifest when no files are given" do
    Puppet[:manifest] = file_containing('site.pp', "{ invalid =>")
    from_an_interactive_terminal

    expect { parser.validate() }.to exit_with(1)
  end

  it "validates the given file" do
    manifest = file_containing('site.pp', "{ invalid =>")
    from_an_interactive_terminal

    expect { parser.validate(manifest) }.to exit_with(1)
  end

  it "validates the contents of STDIN when no files given and STDIN is not a tty" do
    from_a_piped_input_of("{ invalid =>")

    expect { parser.validate() }.to exit_with(1)
  end

  it "runs error free when there are no validation errors" do
    manifest = file_containing('site.pp', "notify { valid: }")
    from_an_interactive_terminal

    parser.validate(manifest)
  end

  it "reports missing files" do
    from_an_interactive_terminal

    expect do
      parser.validate("missing.pp")
    end.to raise_error(Puppet::Error, /One or more file\(s\) specified did not exist.*missing\.pp/m)
  end

  def from_an_interactive_terminal
    STDIN.stubs(:tty?).returns(true)
  end

  def from_a_piped_input_of(contents)
    STDIN.stubs(:tty?).returns(false)
    STDIN.stubs(:read).returns(contents)
  end
end
