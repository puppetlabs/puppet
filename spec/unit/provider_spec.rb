#! /usr/bin/env ruby
require 'spec_helper'

def existing_command
  Puppet.features.microsoft_windows? ? "cmd" : "echo"
end

describe Puppet::Provider do
  before :each do
    Puppet::Type.newtype(:test) do
      newparam(:name) { isnamevar }
    end
  end

  after :each do
    Puppet::Type.rmtype(:test)
  end

  let :type do Puppet::Type.type(:test) end
  let :provider do type.provide(:default) {} end

  subject { provider }

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
        has_command(:does_exist, File.expand_path("/exists/somewhere"))
      end

      file_exists_and_is_executable(File.expand_path("/exists/somewhere"))

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
        commands :always_exists => File.expand_path("/this/command/exists")
      end

      file_exists_and_is_executable(File.expand_path("/this/command/exists"))

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

  it "should have a specifity class method" do
    Puppet::Provider.should respond_to(:specificity)
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

  context "when creating instances" do
    context "with a resource" do
      let :resource do type.new(:name => "fred") end
      subject { provider.new(resource) }

      it "should set the resource correctly" do
        subject.resource.must equal resource
      end

      it "should set the name from the resource" do
        subject.name.should == resource.name
      end
    end

    context "with a hash" do
      subject { provider.new(:name => "fred") }

      it "should set the name" do
        subject.name.should == "fred"
      end

      it "should not have a resource" do subject.resource.should be_nil end
    end

    context "with no arguments" do
      subject { provider.new }

      it "should raise an internal error if asked for the name" do
        expect { subject.name }.to raise_error Puppet::DevError
      end

      it "should not have a resource" do subject.resource.should be_nil end
    end
  end

  context "when confining" do
    it "should be suitable by default" do
      subject.should be_suitable
    end

    it "should not be default by default" do
      subject.should_not be_default
    end

    { { :true => true } => true,
      { :true => false } => false,
      { :false => false } => true,
      { :false => true } => false,
      { :operatingsystem => Facter.value(:operatingsystem) } => true,
      { :operatingsystem => :yayness } => false,
      { :nothing => :yayness } => false,
      { :exists => Puppet::Util.which(existing_command) } => true,
      { :exists => "/this/file/does/not/exist" } => false,
      { :true => true, :exists => Puppet::Util.which(existing_command) } => true,
      { :true => true, :exists => "/this/file/does/not/exist" } => false,
      { :operatingsystem => Facter.value(:operatingsystem),
        :exists => Puppet::Util.which(existing_command) } => true,
      { :operatingsystem => :yayness,
        :exists => Puppet::Util.which(existing_command) } => false,
      { :operatingsystem => Facter.value(:operatingsystem),
        :exists => "/this/file/does/not/exist" } => false,
      { :operatingsystem => :yayness,
        :exists => "/this/file/does/not/exist" } => false,
    }.each do |confines, result|
      it "should confine #{confines.inspect} to #{result}" do
        confines.each {|test, value| subject.confine test => value }
        subject.send(result ? :should : :should_not, be_suitable)
      end
    end

    it "should not override a confine even if a second has the same type" do
      subject.confine :true => false
      subject.should_not be_suitable

      subject.confine :true => true
      subject.should_not be_suitable
    end

    it "should not be suitable if any confine fails" do
      subject.confine :true => false
      subject.should_not be_suitable

      10.times do
        subject.confine :true => true
        subject.should_not be_suitable
      end
    end

  end

  context "default providers" do
    let :os do Facter.value(:operatingsystem) end

    it { should respond_to :specificity }

    it "should find the default provider" do
      type.provide(:nondefault) {}
      subject.defaultfor :operatingsystem => os
      subject.name.should == type.defaultprovider.name
    end

    describe "when there are multiple defaultfor's of equal specificity" do
      before :each do
        subject.defaultfor :operatingsystem => :os1
        subject.defaultfor :operatingsystem => :os2
      end

      let(:alternate) { type.provide(:alternate) {} }

      it "should be default for the first defaultfor" do
        Facter.expects(:value).with(:operatingsystem).at_least_once.returns :os1

        provider.should be_default
        alternate.should_not be_default
      end

      it "should be default for the last defaultfor" do
        Facter.expects(:value).with(:operatingsystem).at_least_once.returns :os2

        provider.should be_default
        alternate.should_not be_default
      end
    end

    describe "when there are multiple defaultfor's with different specificity" do
      before :each do
        subject.defaultfor :operatingsystem => :os1
        subject.defaultfor :operatingsystem => :os2, :operatingsystemmajrelease => "42"
      end

      let(:alternate) { type.provide(:alternate) {} }

      it "should be default for a more specific, but matching, defaultfor" do
        Facter.expects(:value).with(:operatingsystem).at_least_once.returns :os2
        Facter.expects(:value).with(:operatingsystemmajrelease).at_least_once.returns "42"

        provider.should be_default
        alternate.should_not be_default
      end

      it "should be default for a less specific, but matching, defaultfor" do
        Facter.expects(:value).with(:operatingsystem).at_least_once.returns :os1

        provider.should be_default
        alternate.should_not be_default
      end
    end

    it "should consider any true value enough to be default" do
      alternate = type.provide(:alternate) {}

      subject.defaultfor :operatingsystem => [:one, :two, :three, os]
      subject.name.should == type.defaultprovider.name

      subject.should be_default
      alternate.should_not be_default
    end

    it "should not be default if the defaultfor doesn't match" do
      subject.should_not be_default
      subject.defaultfor :operatingsystem => :one
      subject.should_not be_default
    end

    it "should consider two defaults to be higher specificity than one default" do
      Facter.expects(:value).with(:osfamily).at_least_once.returns "solaris"
      Facter.expects(:value).with(:operatingsystemrelease).at_least_once.returns "5.10"

      one = type.provide(:one) do
        defaultfor :osfamily => "solaris"
      end

      two = type.provide(:two) do
        defaultfor :osfamily => "solaris", :operatingsystemrelease => "5.10"
      end

      two.specificity.should > one.specificity
    end

    it "should consider a subclass more specific than its parent class" do
      parent = type.provide(:parent)
      child  = type.provide(:child, :parent => parent)

      child.specificity.should > parent.specificity
    end

    describe "using a :feature key" do
      before :each do
        Puppet.features.add(:yay) do true end
        Puppet.features.add(:boo) do false end
      end

      it "is default for an available feature" do
        one = type.provide(:one) do
          defaultfor :feature => :yay
        end

        one.should be_default
      end

      it "is not default for a missing feature" do
        two = type.provide(:two) do
          defaultfor :feature => :boo
        end

        two.should_not be_default
      end
    end
  end

  context "provider commands" do
    it "should raise for unknown commands" do
      expect { subject.command(:something) }.to raise_error(Puppet::DevError)
    end

    it "should handle command inheritance" do
      parent = type.provide("parent")
      child  = type.provide("child", :parent => parent.name)

      command = Puppet::Util.which('sh') || Puppet::Util.which('cmd.exe')
      parent.commands :sh => command

      Puppet::FileSystem.exist?(parent.command(:sh)).should be_true
      parent.command(:sh).should =~ /#{Regexp.escape(command)}$/

      Puppet::FileSystem.exist?(child.command(:sh)).should be_true
      child.command(:sh).should =~ /#{Regexp.escape(command)}$/
    end

    it "#1197: should find commands added in the same run" do
      subject.commands :testing => "puppet-bug-1197"
      subject.command(:testing).should be_nil

      subject.stubs(:which).with("puppet-bug-1197").returns("/puppet-bug-1197")
      subject.command(:testing).should == "/puppet-bug-1197"

      # Ideally, we would also test that `suitable?` returned the right thing
      # here, but it is impossible to get access to the methods that do that
      # without digging way down into the implementation. --daniel 2012-03-20
    end

    context "with optional commands" do
      before :each do
        subject.optional_commands :cmd => "/no/such/binary/exists"
      end

      it { should be_suitable }

      it "should not be suitable if a mandatory command is also missing" do
        subject.commands :foo => "/no/such/binary/either"
        subject.should_not be_suitable
      end

      it "should define a wrapper for the command" do
        subject.should respond_to(:cmd)
      end

      it "should return nil if the command is requested" do
        subject.command(:cmd).should be_nil
      end

      it "should raise if the command is invoked" do
        expect { subject.cmd }.to raise_error(Puppet::Error, /Command cmd is missing/)
      end
    end
  end

  context "execution" do
    before :each do
      Puppet.expects(:deprecation_warning).never
    end

    it "delegates instance execute to Puppet::Util::Execution" do
      Puppet::Util::Execution.expects(:execute).with("a_command", { :option => "value" })

      provider.new.send(:execute, "a_command", { :option => "value" })
    end

    it "delegates class execute to Puppet::Util::Execution" do
      Puppet::Util::Execution.expects(:execute).with("a_command", { :option => "value" })

      provider.send(:execute, "a_command", { :option => "value" })
    end

    it "delegates instance execpipe to Puppet::Util::Execution" do
      block = Proc.new { }
      Puppet::Util::Execution.expects(:execpipe).with("a_command", true, block)

      provider.new.send(:execpipe, "a_command", true, block)
    end

    it "delegates class execpipe to Puppet::Util::Execution" do
      block = Proc.new { }
      Puppet::Util::Execution.expects(:execpipe).with("a_command", true, block)

      provider.send(:execpipe, "a_command", true, block)
    end

    it "delegates instance execfail to Puppet::Util::Execution" do
      Puppet::Util::Execution.expects(:execfail).with("a_command", "an exception to raise")

      provider.new.send(:execfail, "a_command", "an exception to raise")
    end

    it "delegates class execfail to Puppet::Util::Execution" do
      Puppet::Util::Execution.expects(:execfail).with("a_command", "an exception to raise")

      provider.send(:execfail, "a_command", "an exception to raise")
    end
  end

  context "mk_resource_methods" do
    before :each do
      type.newproperty(:prop)
      type.newparam(:param)
      provider.mk_resource_methods
    end

    let(:instance) { provider.new(nil) }

    it "defaults to :absent" do
      expect(instance.prop).to eq(:absent)
      expect(instance.param).to eq(:absent)
    end

    it "should update when set" do
      instance.prop = 'hello'
      instance.param = 'goodbye'

      expect(instance.prop).to eq('hello')
      expect(instance.param).to eq('goodbye')
    end

    it "treats nil the same as absent" do
      instance.prop = "value"
      instance.param = "value"

      instance.prop = nil
      instance.param = nil

      expect(instance.prop).to eq(:absent)
      expect(instance.param).to eq(:absent)
    end

    it "preserves false as false" do
      instance.prop = false
      instance.param = false

      expect(instance.prop).to eq(false)
      expect(instance.param).to eq(false)
    end
  end

  context "source" do
    it "should default to the provider name" do
      subject.source.should == :default
    end

    it "should default to the provider name for a child provider" do
      type.provide(:sub, :parent => subject.name).source.should == :sub
    end

    it "should override if requested" do
      provider = type.provide(:sub, :parent => subject.name, :source => subject.source)
      provider.source.should == subject.source
    end

    it "should override to anything you want" do
      expect { subject.source = :banana }.to change { subject.source }.
        from(:default).to(:banana)
    end
  end

  context "features" do
    before :each do
      type.feature :numeric,   '', :methods => [:one, :two]
      type.feature :alpha,     '', :methods => [:a, :b]
      type.feature :nomethods, ''
    end

    { :no      => { :alpha => false, :numeric => false, :methods => [] },
      :numeric => { :alpha => false, :numeric => true,  :methods => [:one, :two] },
      :alpha   => { :alpha => true,  :numeric => false, :methods => [:a, :b] },
      :all     => {
        :alpha => true,  :numeric => true,
        :methods => [:a, :b, :one, :two]
      },
      :alpha_and_partial   => {
        :alpha => true, :numeric => false,
        :methods => [:a, :b, :one]
      },
      :numeric_and_partial => {
        :alpha => false, :numeric => true,
        :methods => [:a, :one, :two]
      },
      :all_partial    => { :alpha => false, :numeric => false, :methods => [:a, :one] },
      :other_and_none => { :alpha => false, :numeric => false, :methods => [:foo, :bar] },
      :other_and_alpha => {
        :alpha => true, :numeric => false,
        :methods => [:foo, :bar, :a, :b]
      },
    }.each do |name, setup|
      context "with #{name.to_s.gsub('_', ' ')} features" do
        let :provider do
          provider = type.provide(name)
          setup[:methods].map do |method|
            provider.send(:define_method, method) do true end
          end
          type.provider(name)
        end

        let :numeric? do setup[:numeric] ? :should : :should_not end
        let :alpha?   do setup[:alpha]   ? :should : :should_not end

        subject { provider }

        it { should respond_to(:has_features) }
        it { should respond_to(:has_feature) }

        context "provider class" do
          it { should respond_to(:nomethods?) }
          it { should_not be_nomethods }

          it { should respond_to(:numeric?) }
          it { subject.send(numeric?, be_numeric) }
          it { subject.send(numeric?, be_satisfies(:numeric)) }

          it { should respond_to(:alpha?) }
          it { subject.send(alpha?, be_alpha) }
          it { subject.send(alpha?, be_satisfies(:alpha)) }
        end

        context "provider instance" do
          subject { provider.new }

          it { should respond_to(:numeric?) }
          it { subject.send(numeric?, be_numeric) }
          it { subject.send(numeric?, be_satisfies(:numeric)) }

          it { should respond_to(:alpha?) }
          it { subject.send(alpha?, be_alpha) }
          it { subject.send(alpha?, be_satisfies(:alpha)) }
        end
      end
    end

    context "feature with no methods" do
      before :each do
        type.feature :undemanding, ''
      end

      it { should respond_to(:undemanding?) }

      context "when the feature is not declared" do
        it { should_not be_undemanding }
        it { should_not be_satisfies(:undemanding) }
      end

      context "when the feature is declared" do
        before :each do
          subject.has_feature :undemanding
        end

        it { should be_undemanding }
        it { should be_satisfies(:undemanding) }
      end
    end

    context "supports_parameter?" do
      before :each do
        type.newparam(:no_feature)
        type.newparam(:one_feature,  :required_features => :alpha)
        type.newparam(:two_features, :required_features => [:alpha, :numeric])
      end

      let :providers do
        {
          :zero => type.provide(:zero),
          :one  => type.provide(:one) do has_features :alpha end,
          :two  => type.provide(:two) do has_features :alpha, :numeric end
        }
      end

      { :zero => { :yes => [:no_feature], :no => [:one_feature, :two_features] },
        :one  => { :yes => [:no_feature, :one_feature], :no => [:two_features] },
        :two  => { :yes => [:no_feature, :one_feature, :two_features], :no => [] }
      }.each do |name, data|
        data[:yes].each do |param|
          it "should support #{param} with provider #{name}" do
            providers[name].should be_supports_parameter(param)
          end
        end

        data[:no].each do |param|
          it "should not support #{param} with provider #{name}" do
            providers[name].should_not be_supports_parameter(param)
          end
        end
      end
    end
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
      Puppet::Provider::Command.stubs(:new).with(command.name, command.executable, Puppet::Util, Puppet::Util::Execution, { :failonfail => true, :combine => true, :custom_environment => environment }).returns(command)
  end

  def file_exists_and_is_executable(path)
    FileTest.expects(:file?).with(path).returns(true)
    FileTest.expects(:executable?).with(path).returns(true)
  end
end
