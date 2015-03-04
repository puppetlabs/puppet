#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/application/cert'

describe Puppet::Application::Cert => true do
  before :each do
    @cert_app = Puppet::Application[:cert]
    Puppet::Util::Log.stubs(:newdestination)
  end

  it "should operate in master run_mode" do
    expect(@cert_app.class.run_mode.name).to equal(:master)
  end

  it "should declare a main command" do
    expect(@cert_app).to respond_to(:main)
  end

  Puppet::SSL::CertificateAuthority::Interface::INTERFACE_METHODS.reject{ |m| m == :destroy }.each do |method|
    it "should declare option --#{method}" do
      expect(@cert_app).to respond_to("handle_#{method}".to_sym)
    end
  end

  it "should set log level to info with the --verbose option" do
    @cert_app.handle_verbose(0)
    expect(Puppet::Log.level).to eq(:info)
  end

  it "should set log level to debug with the --debug option" do
    @cert_app.handle_debug(0)
    expect(Puppet::Log.level).to eq(:debug)
  end

  it "should set the fingerprint digest with the --digest option" do
    @cert_app.handle_digest(:digest)
    expect(@cert_app.digest).to eq(:digest)
  end

  it "should set cert_mode to :destroy for --clean" do
    @cert_app.handle_clean(0)
    expect(@cert_app.subcommand).to eq(:destroy)
  end

  it "should set all to true for --all" do
    @cert_app.handle_all(0)
    expect(@cert_app.all).to be_truthy
  end

  it "should set signed to true for --signed" do
    @cert_app.handle_signed(0)
    expect(@cert_app.signed).to be_truthy
  end

  Puppet::SSL::CertificateAuthority::Interface::INTERFACE_METHODS.reject { |m| m == :destroy }.each do |method|
    it "should set cert_mode to #{method} with option --#{method}" do
      @cert_app.send("handle_#{method}".to_sym, nil)

      expect(@cert_app.subcommand).to eq(method)
    end
  end

  describe "during setup" do

    before :each do
      Puppet::Log.stubs(:newdestination)
      Puppet::SSL::Host.stubs(:ca_location=)
      Puppet::SSL::CertificateAuthority.stubs(:new)
    end

    it "should set console as the log destination" do
      Puppet::Log.expects(:newdestination).with(:console)

      @cert_app.setup
    end

    it "should print puppet config if asked to in Puppet config" do
      Puppet.settings.stubs(:print_configs?).returns(true)
      Puppet.settings.expects(:print_configs).returns true
      expect { @cert_app.setup }.to exit_with 0
    end

    it "should exit after printing puppet config if asked to in Puppet config" do
      Puppet.settings.stubs(:print_configs?).returns(true)
      expect { @cert_app.setup }.to exit_with 1
    end

    it "should set the CA location to 'only'" do
      Puppet::SSL::Host.expects(:ca_location=).with(:only)

      @cert_app.setup
    end

    it "should create a new certificate authority" do
      Puppet::SSL::CertificateAuthority.expects(:new)

      @cert_app.setup
    end

    it "should set the ca_location to :local if the cert_mode is generate" do
      @cert_app.subcommand = 'generate'
      Puppet::SSL::Host.expects(:ca_location=).with(:local)
      @cert_app.setup
    end

    it "should set the ca_location to :local if the cert_mode is destroy" do
      @cert_app.subcommand = 'destroy'
      Puppet::SSL::Host.expects(:ca_location=).with(:local)
      @cert_app.setup
    end

    it "should set the ca_location to :only if the cert_mode is print" do
      @cert_app.subcommand = 'print'
      Puppet::SSL::Host.expects(:ca_location=).with(:only)
      @cert_app.setup
    end
  end

  describe "when running" do
    before :each do
      @cert_app.all = false
      @ca = stub_everything 'ca'
      @cert_app.ca = @ca
      @cert_app.command_line.stubs(:args).returns([])
      @iface = stub_everything 'iface'
      Puppet::SSL::CertificateAuthority::Interface.stubs(:new).returns(@iface)
    end

    it "should delegate to the CertificateAuthority" do
      @iface.expects(:apply)

      @cert_app.main
    end

    it "should delegate with :all if option --all was given" do
      @cert_app.handle_all(0)

      Puppet::SSL::CertificateAuthority::Interface.expects(:new).returns(@iface).with { |cert_mode,to| to[:to] == :all }

      @cert_app.main
    end

    it "should delegate to ca.apply with the hosts given on command line" do
      @cert_app.command_line.stubs(:args).returns(["host"])

      Puppet::SSL::CertificateAuthority::Interface.expects(:new).returns(@iface).with { |cert_mode,to| to[:to] == ["host"]}

      @cert_app.main
    end

    it "should send the currently set digest" do
      @cert_app.command_line.stubs(:args).returns(["host"])
      @cert_app.handle_digest(:digest)

      Puppet::SSL::CertificateAuthority::Interface.expects(:new).returns(@iface).with { |cert_mode,to| to[:digest] == :digest}

      @cert_app.main
    end

    it "should revoke cert if cert_mode is clean" do
      @cert_app.subcommand = :destroy
      @cert_app.command_line.stubs(:args).returns(["host"])

      Puppet::SSL::CertificateAuthority::Interface.expects(:new).returns(@iface).with { |cert_mode,to| cert_mode == :revoke }
      Puppet::SSL::CertificateAuthority::Interface.expects(:new).returns(@iface).with { |cert_mode,to| cert_mode == :destroy }

      @cert_app.main
    end
  end

  describe "when identifying subcommands" do
    before :each do
      @cert_app.all = false
      @ca = stub_everything 'ca'
      @cert_app.ca = @ca
    end

    %w{list revoke generate sign print verify fingerprint}.each do |cmd|
      short = cmd[0,1]
      [cmd, "--#{cmd}", "-#{short}"].each do |option|
        # In our command line '-v' was eaten by 'verbose', so we can't consume
        # it here; this is a special case from our otherwise standard
        # processing. --daniel 2011-02-22
        next if option == "-v"

        it "should recognise '#{option}'" do
          args = [option, "fun.example.com"]

          @cert_app.command_line.stubs(:args).returns(args)
          @cert_app.parse_options
          expect(@cert_app.subcommand).to eq(cmd.to_sym)

          expect(args).to eq(["fun.example.com"])
        end
      end
    end

    %w{clean --clean -c}.each do |ugly|
      it "should recognise the '#{ugly}' option as destroy" do
        args = [ugly, "fun.example.com"]

        @cert_app.command_line.stubs(:args).returns(args)
        @cert_app.parse_options
        expect(@cert_app.subcommand).to eq(:destroy)

        expect(args).to eq(["fun.example.com"])
      end
    end

    it "should print help and exit if there is no subcommand" do
      args = []
      @cert_app.command_line.stubs(:args).returns(args)
      @cert_app.stubs(:help).returns("I called for help!")
      @cert_app.expects(:puts).with("I called for help!")

      expect { @cert_app.parse_options }.to exit_with 0
      expect(@cert_app.subcommand).to be_nil
    end
  end
end
