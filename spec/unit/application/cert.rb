#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/application/cert'

describe Puppet::Application::Cert do
    before :each do
        @cert_app = Puppet::Application[:cert]
        Puppet::Util::Log.stubs(:newdestination)
        Puppet::Util::Log.stubs(:level=)
    end

    it "should ask Puppet::Application to parse Puppet configuration file" do
        @cert_app.should_parse_config?.should be_true
    end

    it "should declare a main command" do
        @cert_app.should respond_to(:main)
    end

    Puppet::SSL::CertificateAuthority::Interface::INTERFACE_METHODS.reject{ |m| m == :destroy }.each do |method|
        it "should declare option --#{method}" do
            @cert_app.should respond_to("handle_#{method}".to_sym)
        end
    end

    it "should set log level to info with the --verbose option" do

        Puppet::Log.expects(:level=).with(:info)

        @cert_app.handle_verbose(0)
    end

    it "should set log level to debug with the --debug option" do

        Puppet::Log.expects(:level=).with(:debug)

        @cert_app.handle_debug(0)
    end

    it "should set the fingerprint digest with the --digest option" do
        @cert_app.handle_digest(:digest)

        @cert_app.digest.should == :digest
    end

    it "should set mode to :destroy for --clean" do
        @cert_app.handle_clean(0)
        @cert_app.mode.should == :destroy
    end

    it "should set all to true for --all" do
        @cert_app.handle_all(0)
        @cert_app.all.should be_true
    end

    it "should set signed to true for --signed" do
        @cert_app.handle_signed(0)
        @cert_app.signed.should be_true
    end
    
    Puppet::SSL::CertificateAuthority::Interface::INTERFACE_METHODS.reject { |m| m == :destroy }.each do |method|
        it "should set mode to #{method} with option --#{method}" do
            @cert_app.send("handle_#{method}".to_sym, nil)

            @cert_app.mode.should == method
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
            @cert_app.stubs(:exit)
            Puppet.settings.stubs(:print_configs?).returns(true)

            Puppet.settings.expects(:print_configs)

            @cert_app.setup
        end

        it "should exit after printing puppet config if asked to in Puppet config" do
            Puppet.settings.stubs(:print_configs?).returns(true)

            lambda { @cert_app.setup }.should raise_error(SystemExit)
        end

        it "should set the CA location to 'only'" do
            Puppet::SSL::Host.expects(:ca_location=).with(:only)

            @cert_app.setup
        end

        it "should create a new certificate authority" do
            Puppet::SSL::CertificateAuthority.expects(:new)

            @cert_app.setup
        end
    end

    describe "when running" do
        before :each do
            @cert_app.all = false
            @ca = stub_everything 'ca'
            @cert_app.ca = @ca
            @cert_app.command_line.stubs(:args).returns([])
        end

        it "should delegate to the CertificateAuthority" do
            @ca.expects(:apply)

            @cert_app.main
        end

        it "should delegate with :all if option --all was given" do
            @cert_app.handle_all(0)

            @ca.expects(:apply).with { |mode,to| to[:to] == :all }

            @cert_app.main
        end

        it "should delegate to ca.apply with the hosts given on command line" do
            @cert_app.command_line.stubs(:args).returns(["host"])

            @ca.expects(:apply).with { |mode,to| to[:to] == ["host"]}

            @cert_app.main
        end

        it "should send the currently set digest" do
            @cert_app.command_line.stubs(:args).returns(["host"])
            @cert_app.handle_digest(:digest)

            @ca.expects(:apply).with { |mode,to| to[:digest] == :digest}

            @cert_app.main
        end

        it "should delegate to ca.apply with current set mode" do
            @cert_app.mode = "currentmode"
            @cert_app.command_line.stubs(:args).returns(["host"])

            @ca.expects(:apply).with { |mode,to| mode == "currentmode" }

            @cert_app.main
        end

        it "should revoke cert if mode is clean" do
            @cert_app.mode = :destroy
            @cert_app.command_line.stubs(:args).returns(["host"])

            @ca.expects(:apply).with { |mode,to| mode == :revoke }
            @ca.expects(:apply).with { |mode,to| mode == :destroy }

            @cert_app.main
        end

    end
end
