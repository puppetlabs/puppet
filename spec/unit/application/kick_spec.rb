#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/application/kick'
require 'puppet/run'
require 'puppet/util/ldap/connection'

describe Puppet::Application::Kick, :if => Puppet.features.posix? do
  before :each do
    Puppet::Util::Ldap::Connection.stubs(:new).returns(stub_everything)
    @kick = Puppet::Application[:kick]
    Puppet::Util::Log.stubs(:newdestination)
  end

  describe ".new" do
    it "should take a command-line object as an argument" do
      command_line = Puppet::Util::CommandLine.new("puppet", ['kick', 'myhost'])
      app = Puppet::Application::Kick.new(command_line)

      app.command_line.subcommand_name.should == "kick"
      app.command_line.args.should == ['myhost']
    end
  end

  it "should declare a main command" do
    @kick.should respond_to(:main)
  end

  it "should declare a test command" do
    @kick.should respond_to(:test)
  end

  it "should declare a preinit block" do
    @kick.should respond_to(:preinit)
  end

  describe "during preinit" do
    before :each do
      @kick.stubs(:trap)
    end

    it "should catch INT and TERM" do
      @kick.stubs(:trap).with { |arg,block| arg == :INT or arg == :TERM }

      @kick.preinit
    end

    it "should set parallel option to 1" do
      @kick.preinit

      @kick.options[:parallel].should == 1
    end

    it "should set verbose by default" do
      @kick.preinit

      @kick.options[:verbose].should be_true
    end

    it "should set fqdn by default" do
      @kick.preinit

      @kick.options[:fqdn].should be_true
    end

    it "should set ignoreschedules to 'false'" do
      @kick.preinit

      @kick.options[:ignoreschedules].should be_false
    end

    it "should set foreground to 'false'" do
      @kick.preinit

      @kick.options[:foreground].should be_false
    end
  end

  describe "when applying options" do

    before do
      @kick.preinit
    end

    [:all, :foreground, :debug, :ping, :test, :ignoreschedules].each do |option|
      it "should declare handle_#{option} method" do
        @kick.should respond_to("handle_#{option}".to_sym)
      end

      it "should store argument value when calling handle_#{option}" do
        @kick.options.expects(:[]=).with(option, 'arg')
        @kick.send("handle_#{option}".to_sym, 'arg')
      end
    end

    it "should add to the host list with the host option" do
      @kick.handle_host('host')

      @kick.hosts.should == ['host']
    end

    it "should add to the tag list with the tag option" do
      @kick.handle_tag('tag')

      @kick.tags.should == ['tag']
    end

    it "should add to the class list with the class option" do
      @kick.handle_class('class')

      @kick.classes.should == ['class']
    end
  end

  describe "during setup" do

    before :each do
      @kick.classes = []
      @kick.tags = []
      @kick.hosts = []
      @kick.stubs(:trap)
      @kick.stubs(:puts)

      @kick.options.stubs(:[]).with(any_parameters)
    end

    it "should issue a warning that kick is deprecated" do
      Puppet.expects(:warning).with() { |msg| msg =~ /kick is deprecated/ }
      @kick.setup
    end

    it "should abort stating that kick is not supported on Windows" do
      Puppet.features.stubs(:microsoft_windows?).returns(true)

      expect { @kick.setup }.to raise_error(Puppet::Error, /Puppet kick is not supported on Microsoft Windows/)
    end

    it "should set log level to debug if --debug was passed" do
      @kick.options.stubs(:[]).with(:debug).returns(true)
      @kick.setup
      Puppet::Log.level.should == :debug
    end

    it "should set log level to info if --verbose was passed" do
      @kick.options.stubs(:[]).with(:verbose).returns(true)
      @kick.setup
      Puppet::Log.level.should == :info
    end

    describe "when using the ldap node terminus" do
      before :each do
        Puppet[:node_terminus] = "ldap"
      end

      it "should pass the fqdn option to search" do
        @kick.options.stubs(:[]).with(:fqdn).returns(:something)
        @kick.options.stubs(:[]).with(:all).returns(true)
        @kick.stubs(:puts)

        Puppet::Node.indirection.expects(:search).with("whatever",:fqdn => :something).returns([])

        @kick.setup
      end

      it "should search for all nodes if --all" do
        @kick.options.stubs(:[]).with(:all).returns(true)
        @kick.stubs(:puts)

        Puppet::Node.indirection.expects(:search).with("whatever",:fqdn => nil).returns([])

        @kick.setup
      end

      it "should search for nodes including given classes" do
        @kick.options.stubs(:[]).with(:all).returns(false)
        @kick.stubs(:puts)
        @kick.classes = ['class']

        Puppet::Node.indirection.expects(:search).with("whatever", :class => "class", :fqdn => nil).returns([])

        @kick.setup
      end
    end

    describe "when using regular nodes" do
      it "should fail if some classes have been specified" do
        $stderr.stubs(:puts)
        @kick.classes = ['class']

        expect { @kick.setup }.to exit_with 24
      end
    end
  end

  describe "when running" do
    before :each do
      @kick.stubs(:puts)
    end

    it "should dispatch to test if --test is used" do
      @kick.options.stubs(:[]).with(:test).returns(true)

      @kick.expects(:test)
      @kick.run_command
    end

    it "should dispatch to main if --test is not used" do
      @kick.options.stubs(:[]).with(:test).returns(false)

      @kick.expects(:main)
      @kick.run_command
    end

    describe "the test command" do
      it "should exit with exit code 0 " do
        expect { @kick.test }.to exit_with 0
      end
    end

    describe "the main command" do
      before :each do
        @kick.options.stubs(:[]).with(:parallel).returns(1)
        @kick.options.stubs(:[]).with(:ping).returns(false)
        @kick.options.stubs(:[]).with(:ignoreschedules).returns(false)
        @kick.options.stubs(:[]).with(:foreground).returns(false)
        @kick.options.stubs(:[]).with(:debug).returns(false)
        @kick.options.stubs(:[]).with(:verbose).returns(false) # needed when logging is initialized
        @kick.options.stubs(:[]).with(:setdest).returns(false) # needed when logging is initialized

        @kick.stubs(:print)
        @kick.preinit
        @kick.stubs(:parse_options)
        @kick.setup
        $stderr.stubs(:puts)
      end

      it "should create as much childs as --parallel" do
        @kick.options.stubs(:[]).with(:parallel).returns(3)
        @kick.hosts = ['host1', 'host2', 'host3']
        Process.stubs(:wait).returns(1).then.returns(2).then.returns(3).then.raises(Errno::ECHILD)

        @kick.expects(:safe_posix_fork).times(3).returns(1).then.returns(2).then.returns(3)

        expect { @kick.main }.to raise_error SystemExit
      end

      it "should delegate to run_for_host per host" do
        @kick.hosts = ['host1', 'host2']
        @kick.stubs(:safe_posix_fork).returns(1).yields
        Process.stubs(:wait).returns(1).then.raises(Errno::ECHILD)

        @kick.expects(:run_for_host).times(2)

        lambda { @kick.main }.should raise_error
      end

      describe "during call of run_for_host" do
        before do
          options = {
            :background => true, :ignoreschedules => false, :tags => []
          }
          @kick.preinit
          @agent_run = Puppet::Run.new( options.dup )
          @agent_run.stubs(:status).returns("success")

          # ensure that we don't actually run the agent
          @agent_run.stubs(:run).returns(@agent_run)

          Puppet::Run.indirection.terminus_class = :local
          Puppet::Run.indirection.expects(:terminus_class=).with( :rest )
          Puppet::Run.expects(:new).with( options ).returns(@agent_run)
        end

        it "should call run on a Puppet::Run for the given host" do
          Puppet::Run.indirection.expects(:save).with(@agent_run, 'https://host:8139/production/run/host').returns(@agent_run)
          expect { @kick.run_for_host('host') }.to exit_with 0
        end

        it "should exit the child with 0 on success" do
          @agent_run.stubs(:status).returns("success")
          expect { @kick.run_for_host('host') }.to exit_with 0
        end

        it "should exit the child with 3 on running" do
          @agent_run.stubs(:status).returns("running")
          expect { @kick.run_for_host('host') }.to exit_with 3
        end

        it "should exit the child with 12 on unknown answer" do
          @agent_run.stubs(:status).returns("whatever")
          expect { @kick.run_for_host('host') }.to exit_with 12
        end
      end
    end
  end
end
