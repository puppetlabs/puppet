#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:exec).provider(:posix), :if => Puppet.features.posix? do
  include PuppetSpec::Files

  def make_exe
    cmdpath = tmpdir('cmdpath')
    exepath = tmpfile('my_command', cmdpath)
    FileUtils.touch(exepath)
    File.chmod(0755, exepath)
    exepath
  end

  let(:resource) { Puppet::Type.type(:exec).new(:title => '/foo', :provider => :posix) }
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
      provider.validatecmd("/bin/blah/foo")
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

        Puppet::Util::Execution.expects(:execute).with(filename, instance_of(Hash)).returns(Puppet::Util::Execution::ProcessOutput.new('', 0))

        provider.run(filename)
      end

      it "should fail if the command isn't in the path" do
        resource[:path] = ["/fake/path"]

        expect { provider.run('foo') }.to raise_error(ArgumentError, "Could not find command 'foo'")
      end

      it "should fail if the command is in the path but not executable" do
        command = make_exe
        File.chmod(0644, command)
        FileTest.stubs(:executable?).with(command).returns(false)
        resource[:path] = [File.dirname(command)]
        filename = File.basename(command)

        expect { provider.run(filename) }.to raise_error(ArgumentError, "Could not find command '#{filename}'")
      end
    end

    it "should not be able to execute shell builtins" do
      provider.resource[:path] = ['/bogus/bin']
      expect { provider.run("cd ..") }.to raise_error(ArgumentError, "Could not find command 'cd'")
    end

    it "should execute the command if the command given includes arguments or subcommands" do
      provider.resource[:path] = ['/bogus/bin']
      command = make_exe

      Puppet::Util::Execution.expects(:execute).with("#{command} bar --sillyarg=true --blah", instance_of(Hash)).returns(Puppet::Util::Execution::ProcessOutput.new('', 0))

      provider.run("#{command} bar --sillyarg=true --blah")
    end

    it "should fail if quoted command doesn't exist" do
      provider.resource[:path] = ['/bogus/bin']
      command = "/foo bar --sillyarg=true --blah"

      expect { provider.run(%Q["#{command}"]) }.to raise_error(ArgumentError, "Could not find command '#{command}'")
    end

    it "should warn if you're overriding something in environment" do
      provider.resource[:environment] = ['WHATEVER=/something/else', 'WHATEVER=/foo']
      command = make_exe

      Puppet::Util::Execution.expects(:execute).with(command, instance_of(Hash)).returns(Puppet::Util::Execution::ProcessOutput.new('', 0))

      provider.run(command)

      expect(@logs.map {|l| "#{l.level}: #{l.message}" }).to eq(["warning: Overriding environment setting 'WHATEVER' with '/foo'"])
    end

    it "should set umask before execution if umask parameter is in use" do
      provider.resource[:umask] = '0027'
      Puppet::Util.expects(:withumask).with(0027)
      provider.run(provider.resource[:command])
    end

    describe "posix locale settings" do
      # a sentinel value that we can use to emulate what locale environment variables might be set to on an international
      # system.
      lang_sentinel_value = "en_US.UTF-8"
      # a temporary hash that contains sentinel values for each of the locale environment variables that we override in
      # "exec"
      locale_sentinel_env = {}
      Puppet::Util::POSIX::LOCALE_ENV_VARS.each { |var| locale_sentinel_env[var] = lang_sentinel_value }

      command = "/bin/echo $%s"

      it "should not override user's locale during execution" do
        # we'll do this once without any sentinel values, to give us a little more test coverage
        orig_env = {}
        Puppet::Util::POSIX::LOCALE_ENV_VARS.each { |var| orig_env[var] = ENV[var] if ENV[var] }

        orig_env.keys.each do |var|
          output, status = provider.run(command % var)
          expect(output.strip).to eq(orig_env[var])
        end

        # now, once more... but with our sentinel values
        Puppet::Util.withenv(locale_sentinel_env) do
          Puppet::Util::POSIX::LOCALE_ENV_VARS.each do |var|
            output, status = provider.run(command % var)
            expect(output.strip).to eq(locale_sentinel_env[var])
          end
        end
      end

      it "should respect locale overrides in user's 'environment' configuration" do
        provider.resource[:environment] = ['LANG=C', 'LC_ALL=C']
        output, status = provider.run(command % 'LANG')
        expect(output.strip).to eq('C')
        output, status = provider.run(command % 'LC_ALL')
        expect(output.strip).to eq('C')
      end
    end

    describe "posix user-related environment vars" do
      # a temporary hash that contains sentinel values for each of the user-related environment variables that we
      # are expected to unset during an "exec"
      user_sentinel_env = {}
      Puppet::Util::POSIX::USER_ENV_VARS.each { |var| user_sentinel_env[var] = "Abracadabra" }

      command = "/bin/echo $%s"

      it "should unset user-related environment vars during execution" do
        # first we set up a temporary execution environment with sentinel values for the user-related environment vars
        # that we care about.
        Puppet::Util.withenv(user_sentinel_env) do
          # with this environment, we loop over the vars in question
          Puppet::Util::POSIX::USER_ENV_VARS.each do |var|
            # ensure that our temporary environment is set up as we expect
            expect(ENV[var]).to eq(user_sentinel_env[var])

            # run an "exec" via the provider and ensure that it unsets the vars
            output, status = provider.run(command % var)
            expect(output.strip).to eq("")

            # ensure that after the exec, our temporary env is still intact
            expect(ENV[var]).to eq(user_sentinel_env[var])
          end

        end
      end

      it "should respect overrides to user-related environment vars in caller's 'environment' configuration" do
        sentinel_value = "Abracadabra"
        # set the "environment" property of the resource, populating it with a hash containing sentinel values for
        # each of the user-related posix environment variables
        provider.resource[:environment] = Puppet::Util::POSIX::USER_ENV_VARS.collect { |var| "#{var}=#{sentinel_value}"}

        # loop over the posix user-related environment variables
        Puppet::Util::POSIX::USER_ENV_VARS.each do |var|
          # run an 'exec' to get the value of each variable
          output, status = provider.run(command % var)
          # ensure that it matches our expected sentinel value
          expect(output.strip).to eq(sentinel_value)
        end
      end
    end
  end
end
