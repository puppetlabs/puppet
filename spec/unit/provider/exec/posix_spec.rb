#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Type.type(:exec).provider(:posix) do
  include PuppetSpec::Files

  def make_exe
    command = tmpfile('my_command')
    FileUtils.touch(command)
    File.chmod(0755, command)
    command
  end

  let(:resource) { Puppet::Type.type(:exec).new(:title => File.expand_path('/foo'), :provider => :posix) }
  let(:provider) { described_class.new(resource) }

  describe "#validatecmd" do
    it "should fail if no path is specified and the command is not fully qualified" do
      expect { provider.validatecmd("foo") }.to raise_error(
        Puppet::Error,
        "'foo' is not qualified and no path was specified. Please qualify the command or specify a path."
      )
    end

    it "should pass if a path is given" do
      provider.resource[:path] = ['/bogus/bin']
      provider.validatecmd("../foo")
    end

    it "should pass if command is fully qualifed" do
      provider.resource[:path] = ['/bogus/bin']
      provider.validatecmd(File.expand_path("/bin/blah/foo"))
    end
  end

  describe "#run" do
    describe "when the command is an absolute path" do
      let(:command) { tmpfile('foo') }

      it "should fail if the command doesn't exist" do
        expect { provider.run(command) }.to raise_error(ArgumentError, "Could not find command '#{command}'")
      end

      it "should fail if the command isn't a file" do
        FileUtils.mkdir(command)
        FileUtils.chmod(0755, command)

        expect { provider.run(command) }.to raise_error(ArgumentError, "'#{command}' is a directory, not a file")
      end

      it "should fail if the command isn't executable" do
        FileUtils.touch(command)
        File.stubs(:executable?).with(command).returns(false)

        expect { provider.run(command) }.to raise_error(ArgumentError, "'#{command}' is not executable")
      end
    end

    describe "when the command is a relative path" do
      it "should execute the command if it finds it in the path and is executable" do
        command = make_exe
        provider.resource[:path] = [File.dirname(command)]
        filename = File.basename(command)

        Puppet::Util.expects(:execute).with { |cmdline, arguments| (cmdline == filename) && (arguments.is_a? Hash) }

        provider.run(filename)
      end

      it "should fail if the command isn't in the path" do
        resource[:path] = ["/fake/path"]

        expect { provider.run('foo') }.to raise_error(ArgumentError, "Could not find command 'foo'")
      end

      it "should fail if the command is in the path but not executable" do
        command = tmpfile('foo')
        FileUtils.touch(command)
        FileTest.stubs(:executable?).with(command).returns(false)
        resource[:path] = [File.dirname(command)]
        filename = File.basename(command)

        expect { provider.run(filename) }.to raise_error(ArgumentError, "Could not find command '#{filename}'")
      end
    end

    it "should not be able to execute shell builtins" do
      provider.resource[:path] = ['/bin']
      expect { provider.run("cd ..") }.to raise_error(ArgumentError, "Could not find command 'cd'")
    end

    it "should execute the command if the command given includes arguments or subcommands" do
      provider.resource[:path] = ['/bogus/bin']
      command = make_exe

      Puppet::Util.expects(:execute).with { |cmdline, arguments| (cmdline == "#{command} bar --sillyarg=true --blah") && (arguments.is_a? Hash) }
      provider.run("#{command} bar --sillyarg=true --blah")
    end

    it "should fail if quoted command doesn't exist" do
      provider.resource[:path] = ['/bogus/bin']
      command = "#{File.expand_path('/foo')} bar --sillyarg=true --blah"

      expect { provider.run(%Q["#{command}"]) }.to raise_error(ArgumentError, "Could not find command '#{command}'")
    end

    it "should warn if you're overriding something in environment" do
      provider.resource[:environment] = ['WHATEVER=/something/else', 'WHATEVER=/foo']
      command = make_exe

      Puppet::Util.expects(:execute).with { |cmdline, arguments| (cmdline == command) && (arguments.is_a? Hash) }
      provider.run(command)
      @logs.map {|l| "#{l.level}: #{l.message}" }.should == ["warning: Overriding environment setting 'WHATEVER' with '/foo'"]
    end
  end
end
