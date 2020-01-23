require 'spec_helper'

require 'puppet/application/describe'

describe Puppet::Application::Describe do
  let(:describe) { Puppet::Application[:describe] }

  it "lists all types" do
    describe.command_line.args << '--list'

    expect {
      describe.run
    }.to output(/These are the types known to puppet:/).to_stdout
  end

  it "describes a single type" do
    describe.command_line.args << 'exec'

    expect {
      describe.run
    }.to output(/exec.*====.*Executes external commands/m).to_stdout
  end

  it "describes multiple types" do
    describe.command_line.args.concat(['exec', 'file'])

    expect {
      describe.run
    }.to output(/Executes external commands.*Manages files, including their content, ownership, and permissions./m).to_stdout
  end

  it "describes parameters for the type by default" do
    describe.command_line.args << 'exec'

    expect {
      describe.run
    }.to output(/Parameters\n----------/m).to_stdout
  end

  it "lists parameter names, but excludes description in short mode" do
    describe.command_line.args.concat(['exec', '-s'])

    expect {
      describe.run
    }.to output(/Parameters.*command, creates, cwd/m).to_stdout
  end

  it "outputs providers for the type" do
    describe.command_line.args.concat(['exec', '--providers'])

    expect {
      describe.run
    }.to output(/Providers.*#{Regexp.escape('**posix**')}.*#{Regexp.escape('**windows**')}/m).to_stdout
  end

  it "lists metaparameters for a type" do
    describe.command_line.args.concat(['exec', '--meta'])

    expect {
      describe.run
    }.to output(/Meta Parameters.*#{Regexp.escape('**notify**')}/m).to_stdout
  end

  it "formats text with long non-space runs without garbling" do
    f = Formatter.new(76)

    teststring = <<TESTSTRING
. 12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890 nick@magpie.puppetlabs.lan
**this part should not repeat!**
TESTSTRING

    expected_result = <<EXPECTED
.
1234567890123456789012345678901234567890123456789012345678901234567890123456
7890123456789012345678901234567890 nick@magpie.puppetlabs.lan
**this part should not repeat!**
EXPECTED

    result = f.wrap(teststring, {:indent => 0, :scrub => true})
    expect(result).to eql(expected_result)
  end
end
