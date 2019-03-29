require 'spec_helper'
require 'puppet/application/cert'

describe Puppet::Application::Cert => true do
  before :each do
    @cert_app = Puppet::Application[:cert]
    allow(Puppet::Util::Log).to receive(:newdestination)
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

  it "should set human to true for --human-readable" do
    @cert_app.handle_human_readable(0)
    expect(@cert_app.options[:format]).to be :human
  end

  it "should set machine to true for --machine-readable" do
    @cert_app.handle_machine_readable(0)
    expect(@cert_app.options[:format]).to be :machine
  end

  it "should set interactive to true for --interactive" do
    @cert_app.handle_interactive(0)
    expect(@cert_app.options[:interactive]).to be_truthy
  end

  it "should set yes to true for --assume-yes" do
    @cert_app.handle_assume_yes(0)
    expect(@cert_app.options[:yes]).to be_truthy
  end

  Puppet::SSL::CertificateAuthority::Interface::INTERFACE_METHODS.reject { |m| m == :destroy }.each do |method|
    it "should set cert_mode to #{method} with option --#{method}" do
      @cert_app.send("handle_#{method}".to_sym, nil)

      expect(@cert_app.subcommand).to eq(method)
    end
  end

  describe "during setup" do

    before :each do
      allow(Puppet::Log).to receive(:newdestination)
      allow(Puppet::SSL::Host).to receive(:ca_location=)
      allow(Puppet::SSL::CertificateAuthority).to receive(:new)
    end

    it "should set console as the log destination" do
      expect(Puppet::Log).to receive(:newdestination).with(:console)

      @cert_app.setup
    end

    it "should print puppet config if asked to in Puppet config" do
      allow(Puppet.settings).to receive(:print_configs?).and_return(true)
      expect(Puppet.settings).to receive(:print_configs).and_return(true)
      expect { @cert_app.setup }.to exit_with 0
    end

    it "should exit after printing puppet config if asked to in Puppet config" do
      allow(Puppet.settings).to receive(:print_configs?).and_return(true)
      expect { @cert_app.setup }.to exit_with 1
    end

    it "should set the CA location to 'only'" do
      expect(Puppet::SSL::Host).to receive(:ca_location=).with(:only)

      @cert_app.setup
    end

    it "should create a new certificate authority" do
      expect(Puppet::SSL::CertificateAuthority).to receive(:new)

      @cert_app.setup
    end

    it "should set the ca_location to :local if the cert_mode is generate" do
      @cert_app.subcommand = 'generate'
      expect(Puppet::SSL::Host).to receive(:ca_location=).with(:local)
      @cert_app.setup
    end

    it "should set the ca_location to :local if the cert_mode is destroy" do
      @cert_app.subcommand = 'destroy'
      expect(Puppet::SSL::Host).to receive(:ca_location=).with(:local)
      @cert_app.setup
    end

    it "should set the ca_location to :only if the cert_mode is print" do
      @cert_app.subcommand = 'print'
      expect(Puppet::SSL::Host).to receive(:ca_location=).with(:only)
      @cert_app.setup
    end
  end

  describe "when running" do
    before :each do
      @cert_app.all = false
      @ca = double('ca', :waiting? => ['unsigned-node'])
      @cert_app.ca = @ca
      allow(@cert_app.command_line).to receive(:args).and_return([])
      @iface = double('iface', apply: nil)
      allow(Puppet::SSL::CertificateAuthority::Interface).to receive(:new).and_return(@iface)
    end

    it "should delegate to the CertificateAuthority" do
      expect(@iface).to receive(:apply)

      @cert_app.main
    end

    it "should delegate with :all if option --all was given" do
      @cert_app.handle_all(0)

      expect(Puppet::SSL::CertificateAuthority::Interface).to receive(:new).with(anything, hash_including(to: :all)).and_return(@iface)

      @cert_app.main
    end

    it "should delegate to ca.apply with the hosts given on command line" do
      allow(@cert_app.command_line).to receive(:args).and_return(["host"])

      expect(Puppet::SSL::CertificateAuthority::Interface).to receive(:new).with(anything, hash_including(to: ["host"])).and_return(@iface)

      @cert_app.main
    end

    it "should send the currently set digest" do
      allow(@cert_app.command_line).to receive(:args).and_return(["host"])
      @cert_app.handle_digest(:digest)

      expect(Puppet::SSL::CertificateAuthority::Interface).to receive(:new).with(anything, hash_including(digest: :digest)).and_return(@iface)

      @cert_app.main
    end

    it "should revoke cert if cert_mode is clean" do
      @cert_app.subcommand = :destroy
      allow(@cert_app.command_line).to receive(:args).and_return(["host"])

      expect(Puppet::SSL::CertificateAuthority::Interface).to receive(:new).with(:revoke, anything).and_return(@iface)
      expect(Puppet::SSL::CertificateAuthority::Interface).to receive(:new).with(:destroy, anything).and_return(@iface)

      @cert_app.main
    end

    it "should not revoke cert if node does not have a signed certificate" do
      @cert_app.subcommand = :destroy
      allow(@cert_app.command_line).to receive(:args).and_return(["unsigned-node"])

      allow(Puppet::SSL::CertificateAuthority::Interface).to receive(:new).and_call_original
      expect(Puppet::SSL::CertificateAuthority::Interface).not_to receive(:new).with(:revoke, anything)
      expect(Puppet::SSL::CertificateAuthority::Interface).to receive(:new).with(:destroy, {:to => ['unsigned-node'], :digest => nil}).and_return(@iface)

      @cert_app.main
    end

    it "should only revoke signed certificate and destroy certificate signing requests" do
      @cert_app.subcommand = :destroy
      allow(@cert_app.command_line).to receive(:args).and_return(["host","unsigned-node"])

      expect(Puppet::SSL::CertificateAuthority::Interface).to receive(:new).with(:revoke, hash_including(to: ["host"])).and_return(@iface)
      expect(Puppet::SSL::CertificateAuthority::Interface).to receive(:new).with(:destroy, hash_including(to: ["host", "unsigned-node"])).and_return(@iface)

      @cert_app.main
    end

    it "should refuse to destroy all certificates" do
      @cert_app.subcommand = :destroy
      @cert_app.all = true

      allow(Puppet::SSL::CertificateAuthority::Interface).to receive(:new).and_call_original
      expect(Puppet::SSL::CertificateAuthority::Interface).not_to receive(:new)

      expect(Puppet).to receive(:log_exception) {|e| expect(e.message).to eq("Refusing to destroy all certs, provide an explicit list of certs to destroy")}

      expect { @cert_app.main }.to exit_with(24)
    end
  end

  describe "when identifying subcommands" do
    before :each do
      @cert_app.all = false
      @ca = double('ca')
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

          allow(@cert_app.command_line).to receive(:args).and_return(args)
          @cert_app.parse_options
          expect(@cert_app.subcommand).to eq(cmd.to_sym)

          expect(args).to eq(["fun.example.com"])
        end
      end
    end

    %w{clean --clean -c}.each do |ugly|
      it "should recognise the '#{ugly}' option as destroy" do
        args = [ugly, "fun.example.com"]

        allow(@cert_app.command_line).to receive(:args).and_return(args)
        @cert_app.parse_options
        expect(@cert_app.subcommand).to eq(:destroy)

        expect(args).to eq(["fun.example.com"])
      end
    end

    it "should print help and exit if there is no subcommand" do
      args = []
      allow(@cert_app.command_line).to receive(:args).and_return(args)
      allow(@cert_app).to receive(:help).and_return("I called for help!")
      expect(@cert_app).to receive(:puts).with("I called for help!")

      expect { @cert_app.parse_options }.to exit_with 0
      expect(@cert_app.subcommand).to be_nil
    end
  end
end
