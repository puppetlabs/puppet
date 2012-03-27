require 'spec_helper'

describe Puppet::Provider do
  after do
    Puppet::Type.rmtype(:dummy)
  end

  describe "has command" do
    it "installs a method to run the command specified by the path" do
      echo_command = expect_command_executed(:echo, "/bin/echo", "an argument")
      allow_creation_of(echo_command)

      provider = provider_of do
        has_command(:echo, "/bin/echo")
      end

      provider.echo("an argument")
    end

    it "installs a command that is run with a given environment" do
      echo_command = expect_command_executed(:echo, "/bin/echo", "an argument")
      allow_creation_of(echo_command, {
        :EV => "value",
        :OTHER => "different"
      })

      provider = provider_of do
        has_command(:echo, "/bin/echo") do
          environment :EV => "value", :OTHER => "different"
        end
      end

      provider.echo("an argument")
    end

    it "is required by default" do
      provider = provider_of do
        has_command(:does_not_exist, "/does/not/exist")
      end

      provider.should_not be_suitable
    end

    it "is required by default" do
      provider = provider_of do
        has_command(:does_exist, "/exists/somewhere")
      end

      file_exists_and_is_executable("/exists/somewhere")

      provider.should be_suitable
    end

    it "can be specified as optional" do
      provider = provider_of do
        has_command(:does_not_exist, "/does/not/exist") do
          is_optional
        end
      end

      provider.should be_suitable
    end
  end

  describe "has required commands" do
    it "installs methods to run executables by path" do
      echo_command = expect_command_executed(:echo, "/bin/echo", "an argument")
      ls_command = expect_command_executed(:ls, "/bin/ls")

      allow_creation_of(echo_command)
      allow_creation_of(ls_command)

      provider = provider_of do
        commands :echo => "/bin/echo", :ls => "/bin/ls"
      end

      provider.echo("an argument")
      provider.ls
    end

    it "allows the provider to be suitable if the executable is present" do
      provider = provider_of do
        commands :always_exists => "/this/command/exists"
      end

      file_exists_and_is_executable("/this/command/exists")

      provider.should be_suitable
    end

    it "does not allow the provider to be suitable if the executable is not present" do
      provider = provider_of do
        commands :does_not_exist => "/this/command/does/not/exist"
      end

      provider.should_not be_suitable
    end
  end

  describe "has optional commands" do
    it "installs methods to run executables" do
      echo_command = expect_command_executed(:echo, "/bin/echo", "an argument")
      ls_command = expect_command_executed(:ls, "/bin/ls")

      allow_creation_of(echo_command)
      allow_creation_of(ls_command)

      provider = provider_of do
        optional_commands :echo => "/bin/echo", :ls => "/bin/ls"
      end

      provider.echo("an argument")
      provider.ls
    end

    it "allows the provider to be suitable even if the executable is not present" do
      provider = provider_of do
        optional_commands :does_not_exist => "/this/command/does/not/exist"
      end

      provider.should be_suitable
    end
  end

  it "makes command methods on demand (deprecated)" do
    Puppet::Util.expects(:which).with("/not/a/command").returns("/not/a/command")
    Puppet::Util::Execution.expects(:execute).with(["/not/a/command"], {})

    provider = provider_of do
      @commands[:echo] = "/not/a/command"
    end
    provider.stubs(:which).with("/not/a/command").returns("/not/a/command")

    provider.make_command_methods(:echo)
    provider.echo
  end

  it "should consider two defaults to be higher specificity than one default" do
    one = provider_of do
      defaultfor :operatingsystem => "solaris"
    end

    two = provider_of do
      defaultfor :operatingsystem => "solaris", :operatingsystemrelease => "5.10"
    end

    two.specificity.should > one.specificity
  end

  it "should consider a subclass more specific than its parent class" do
    one = provider_of {}

    two = provider_of({ :parent => one }) {}

    two.specificity.should > one.specificity
  end

  it "should be Comparable" do
    res = Puppet::Type.type(:notify).new(:name => "res")

    # Normally I wouldn't like the stubs, but the only way to name a class
    # otherwise is to assign it to a constant, and that hurts more here in
    # testing world. --daniel 2012-01-29
    a = Class.new(Puppet::Provider).new(res)
    a.class.stubs(:name).returns "Puppet::Provider::Notify::A"

    b = Class.new(Puppet::Provider).new(res)
    b.class.stubs(:name).returns "Puppet::Provider::Notify::B"

    c = Class.new(Puppet::Provider).new(res)
    c.class.stubs(:name).returns "Puppet::Provider::Notify::C"

    [[a, b, c], [a, c, b], [b, a, c], [b, c, a], [c, a, b], [c, b, a]].each do |this|
      this.sort.should == [a, b, c]
    end

    a.should be < b
    a.should be < c
    b.should be > a
    b.should be < c
    c.should be > a
    c.should be > b

    [a, b, c].each {|x| a.should be <= x }
    [a, b, c].each {|x| c.should be >= x }

    b.should be_between(a, c)
  end

  def provider_of(options = {}, &block) 
    type = Puppet::Type.newtype(:dummy) do
      provide(:dummy, options, &block)
    end

    type.provider(:dummy)
  end

  def expect_command_executed(name, path, *args) 
    command = Puppet::Provider::Command.new(name, path, Puppet::Util, Puppet::Util::Execution)
    command.expects(:execute).with(*args)
    command
  end

  def allow_creation_of(command, environment = {})
      Puppet::Provider::Command.stubs(:new).with(command.name, command.executable, Puppet::Util, Puppet::Util::Execution, { :custom_environment => environment }).returns(command)
  end

  def file_exists_and_is_executable(path) 
    FileTest.expects(:file?).with(path).returns(true)
    FileTest.expects(:executable?).with(path).returns(true)
  end
end
