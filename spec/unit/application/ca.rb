#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/application/ca'

describe "PuppetCA" do
    before :each do
        @ca_app = Puppet::Application[:ca]
        Puppet::Util::Log.stubs(:newdestination)
        Puppet::Util::Log.stubs(:level=)
    end

    it "should ask Puppet::Application to parse Puppet configuration file" do
        @ca_app.should_parse_config?.should be_true
    end

    it "should declare a main command" do
        @ca_app.should respond_to(:main)
    end

    Puppet::SSL::CertificateAuthority::Interface::INTERFACE_METHODS.reject{ |m| m == :destroy }.each do |method|
        it "should declare option --#{method}" do
            @ca_app.should respond_to("handle_#{method}".to_sym)
        end
    end

    it "should set log level to info with the --verbose option" do

        Puppet::Log.expects(:level=).with(:info)

        @ca_app.handle_verbose(0)
    end

    it "should set log level to debug with the --debug option" do

        Puppet::Log.expects(:level=).with(:debug)

        @ca_app.handle_debug(0)
    end

    it "should set the fingerprint digest with the --digest option" do
        @ca_app.handle_digest(:digest)

        @ca_app.digest.should == :digest
    end

    it "should set mode to :destroy for --clean" do
        @ca_app.handle_clean(0)
        @ca_app.mode.should == :destroy
    end

    it "should set all to true for --all" do
        @ca_app.handle_all(0)
        @ca_app.all.should be_true
    end

    Puppet::SSL::CertificateAuthority::Interface::INTERFACE_METHODS.reject { |m| m == :destroy }.each do |method|
        it "should set mode to #{method} with option --#{method}" do
            @ca_app.send("handle_#{method}".to_sym, nil)

            @ca_app.mode.should == method
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

            @ca_app.run_setup
        end

        it "should print puppet config if asked to in Puppet config" do
            @ca_app.stubs(:exit)
            Puppet.settings.stubs(:print_configs?).returns(true)

            Puppet.settings.expects(:print_configs)

            @ca_app.run_setup
        end

        it "should exit after printing puppet config if asked to in Puppet config" do
            Puppet.settings.stubs(:print_configs?).returns(true)

            lambda { @ca_app.run_setup }.should raise_error(SystemExit)
        end

        it "should set the CA location to 'only'" do
            Puppet::SSL::Host.expects(:ca_location=).with(:only)

            @ca_app.run_setup
        end

        it "should create a new certificate authority" do
            Puppet::SSL::CertificateAuthority.expects(:new)

            @ca_app.run_setup
        end
    end

    describe "when running" do
        before :each do
            @ca_app.all = false
            @ca = stub_everything 'ca'
            @ca_app.ca = @ca
            ARGV.stubs(:collect).returns([])
        end

        it "should delegate to the CertificateAuthority" do
            @ca.expects(:apply)

            @ca_app.main
        end

        it "should delegate with :all if option --all was given" do
            @ca_app.handle_all(0)

            @ca.expects(:apply).with { |mode,to| to[:to] == :all }

            @ca_app.main
        end

        it "should delegate to ca.apply with the hosts given on command line" do
            ARGV.stubs(:collect).returns(["host"])

            @ca.expects(:apply).with { |mode,to| to[:to] == ["host"]}

            @ca_app.main
        end

        it "should send the currently set digest" do
            ARGV.stubs(:collect).returns(["host"])
            @ca_app.handle_digest(:digest)

            @ca.expects(:apply).with { |mode,to| to[:digest] == :digest}

            @ca_app.main
        end

        it "should delegate to ca.apply with current set mode" do
            @ca_app.mode = "currentmode"
            ARGV.stubs(:collect).returns(["host"])

            @ca.expects(:apply).with { |mode,to| mode == "currentmode" }

            @ca_app.main
        end

        it "should revoke cert if mode is clean" do
            @ca_app.mode = :destroy
            ARGV.stubs(:collect).returns(["host"])

            @ca.expects(:apply).with { |mode,to| mode == :revoke }
            @ca.expects(:apply).with { |mode,to| mode == :destroy }

            @ca_app.main
        end

    end
end
