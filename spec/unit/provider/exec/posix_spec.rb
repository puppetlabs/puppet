#!/usr/bin/env rspec
require 'spec_helper'

provider_class = Puppet::Type.type(:exec).provider(:posix)

describe provider_class do
  before :each do
    @resource = Puppet::Resource.new(:exec, 'foo')
    @provider = provider_class.new(@resource)
  end

  ["posix", "microsoft_windows"].each do |feature|
    describe "when in #{feature} environment" do
      before :each do
        if feature == "microsoft_windows"
          Puppet.features.stubs(:microsoft_windows?).returns(true)
          Puppet.features.stubs(:posix?).returns(false)
        else
          Puppet.features.stubs(:posix?).returns(true)
          Puppet.features.stubs(:microsoft_windows?).returns(false)
        end
      end

      describe "#validatecmd" do
        it "should fail if no path is specified and the command is not fully qualified" do
          lambda { @provider.validatecmd("foo") }.should raise_error(
            Puppet::Error,
            "'foo' is not qualified and no path was specified. Please qualify the command or specify a path."
          )
        end

        it "should pass if a path is given" do
          @provider.resource[:path] = ['/bogus/bin']
          @provider.validatecmd("../foo")
        end

        it "should pass if command is fully qualifed" do
          @provider.resource[:path] = ['/bogus/bin']
          @provider.validatecmd("/bin/blah/foo")
        end
      end

      describe "#run" do
        it "should fail if no path is specified and command does not exist" do
          lambda { @provider.run("foo") }.should raise_error(ArgumentError, "Could not find command 'foo'")
        end

        it "should fail if the command isn't in the path" do
          @provider.resource[:path] = ['/bogus/bin']
          lambda { @provider.run("foo") }.should raise_error(ArgumentError, "Could not find command 'foo'")
        end

        it "should fail if the command isn't executable" do
          @provider.resource[:path] = ['/bogus/bin']
          File.stubs(:exists?).with("foo").returns(true)

          lambda { @provider.run("foo") }.should raise_error(ArgumentError, "'foo' is not executable")
        end

        it "should not be able to execute shell builtins" do
          @provider.resource[:path] = ['/bin']
          lambda { @provider.run("cd ..") }.should raise_error(ArgumentError, "Could not find command 'cd'")
        end

        it "should execute the command if the command given includes arguments or subcommands" do
          @provider.resource[:path] = ['/bogus/bin']
          File.stubs(:exists?).returns(false)
          File.stubs(:exists?).with("foo").returns(true)
          File.stubs(:executable?).with("foo").returns(true)

          Puppet::Util.expects(:execute).with() { |command, arguments| (command == ['foo bar --sillyarg=true --blah']) && (arguments.is_a? Hash) }
          @provider.run("foo bar --sillyarg=true --blah")
        end

        it "should fail if quoted command doesn't exist" do
          @provider.resource[:path] = ['/bogus/bin']
          File.stubs(:exists?).returns(false)
          File.stubs(:exists?).with("foo").returns(true)
          File.stubs(:executable?).with("foo").returns(true)

          lambda { @provider.run('"foo bar --sillyarg=true --blah"') }.should raise_error(ArgumentError, "Could not find command 'foo bar --sillyarg=true --blah'")
        end

        it "should execute the command if it finds it in the path and is executable" do
          @provider.resource[:path] = ['/bogus/bin']
          File.stubs(:exists?).with("foo").returns(true)
          File.stubs(:executable?).with("foo").returns(true)
          Puppet::Util.expects(:execute).with() { |command, arguments| (command == ['foo']) && (arguments.is_a? Hash) }

          @provider.run("foo")
        end

        if feature == "microsoft_windows"
          [".exe", ".ps1", ".bat", ".com", ""].each do |extension|
            it "should check file extension #{extension} when it can't find the executable" do
              @provider.resource[:path] = ['/bogus/bin']
              File.stubs(:exists?).returns(false)
              File.stubs(:exists?).with("/bogus/bin/foo#{extension}").returns(true)
              File.stubs(:executable?).with("foo").returns(true)
              Puppet::Util.expects(:execute).with() { |command, arguments| (command == ['foo']) && (arguments.is_a? Hash) }

              @provider.run("foo")
            end
          end
        end

        it "should warn if you're overriding something in environment" do
          @provider.resource[:environment] = ['WHATEVER=/something/else', 'WHATEVER=/foo']
          File.stubs(:exists?).returns(false)
          File.stubs(:exists?).with("foo").returns(true)
          File.stubs(:executable?).with("foo").returns(true)

          Puppet::Util.expects(:execute).with() { |command, arguments| (command == ['foo']) && (arguments.is_a? Hash) }
          @provider.run("foo")
          @logs.map {|l| "#{l.level}: #{l.message}" }.should == ["warning: Overriding environment setting 'WHATEVER' with '/foo'"]
        end
      end
    end
  end
end
