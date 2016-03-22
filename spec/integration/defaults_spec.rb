#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/defaults'

describe "Puppet defaults" do

  describe "when default_manifest is set" do
    it "returns ./manifests by default" do
      expect(Puppet[:default_manifest]).to eq('./manifests')
    end
  end

  describe "when disable_per_environment_manifest is set" do
    it "returns false by default" do
      expect(Puppet[:disable_per_environment_manifest]).to eq(false)
    end

    it "errors when set to true and default_manifest is not an absolute path" do
      expect {
        Puppet[:default_manifest] = './some/relative/manifest.pp'
        Puppet[:disable_per_environment_manifest] = true
      }.to raise_error Puppet::Settings::ValidationError, /'default_manifest' setting must be.*absolute/
    end
  end

  describe "when setting the :factpath" do
    it "should add the :factpath to Facter's search paths" do
      Facter.expects(:search).with("/my/fact/path")

      Puppet.settings[:factpath] = "/my/fact/path"
    end
  end

  describe "when setting the :certname" do
    it "should fail if the certname is not downcased" do
      expect { Puppet.settings[:certname] = "Host.Domain.Com" }.to raise_error(ArgumentError)
    end
  end

  describe "when setting :node_name_value" do
    it "should default to the value of :certname" do
      Puppet.settings[:certname] = 'blargle'
      expect(Puppet.settings[:node_name_value]).to eq('blargle')
    end
  end

  describe "when setting the :node_name_fact" do
    it "should fail when also setting :node_name_value" do
      expect do
        Puppet.settings[:node_name_value] = "some value"
        Puppet.settings[:node_name_fact] = "some_fact"
      end.to raise_error("Cannot specify both the node_name_value and node_name_fact settings")
    end

    it "should not fail when using the default for :node_name_value" do
      expect do
        Puppet.settings[:node_name_fact] = "some_fact"
      end.not_to raise_error
    end
  end

  it "should have a clientyamldir setting" do
    expect(Puppet.settings[:clientyamldir]).not_to be_nil
  end

  it "should have different values for the yamldir and clientyamldir" do
    expect(Puppet.settings[:yamldir]).not_to eq(Puppet.settings[:clientyamldir])
  end

  it "should have a client_datadir setting" do
    expect(Puppet.settings[:client_datadir]).not_to be_nil
  end

  it "should have different values for the server_datadir and client_datadir" do
    expect(Puppet.settings[:server_datadir]).not_to eq(Puppet.settings[:client_datadir])
  end

  # See #1232
  it "should not specify a user or group for the clientyamldir" do
    expect(Puppet.settings.setting(:clientyamldir).owner).to be_nil
    expect(Puppet.settings.setting(:clientyamldir).group).to be_nil
  end

  it "should use the service user and group for the yamldir" do
    Puppet.settings.stubs(:service_user_available?).returns true
    Puppet.settings.stubs(:service_group_available?).returns true
    expect(Puppet.settings.setting(:yamldir).owner).to eq(Puppet.settings[:user])
    expect(Puppet.settings.setting(:yamldir).group).to eq(Puppet.settings[:group])
  end

  it "should specify that the host private key should be owned by the service user" do
    Puppet.settings.stubs(:service_user_available?).returns true
    expect(Puppet.settings.setting(:hostprivkey).owner).to eq(Puppet.settings[:user])
  end

  it "should specify that the host certificate should be owned by the service user" do
    Puppet.settings.stubs(:service_user_available?).returns true
    expect(Puppet.settings.setting(:hostcert).owner).to eq(Puppet.settings[:user])
  end

  [:modulepath, :factpath].each do |setting|
    it "should configure '#{setting}' not to be a file setting, so multi-directory settings are acceptable" do
      expect(Puppet.settings.setting(setting)).to be_instance_of(Puppet::Settings::PathSetting)
    end
  end

  describe "on a Unix-like platform it", :if => Puppet.features.posix? do
    it "should add /usr/sbin and /sbin to the path if they're not there" do
      Puppet::Util.withenv("PATH" => "/usr/bin#{File::PATH_SEPARATOR}/usr/local/bin") do
        Puppet.settings[:path] = "none" # this causes it to ignore the setting
        expect(ENV["PATH"].split(File::PATH_SEPARATOR)).to be_include("/usr/sbin")
        expect(ENV["PATH"].split(File::PATH_SEPARATOR)).to be_include("/sbin")
      end
    end
  end

  describe "on a Windows-like platform it", :if => Puppet.features.microsoft_windows? do
    let (:rune_utf8) { "\u16A0\u16C7\u16BB\u16EB\u16D2\u16E6\u16A6\u16EB\u16A0\u16B1\u16A9\u16A0\u16A2\u16B1\u16EB\u16A0\u16C1\u16B1\u16AA\u16EB\u16B7\u16D6\u16BB\u16B9\u16E6\u16DA\u16B3\u16A2\u16D7" }

    it "path should not add anything" do
      path = "c:\\windows\\system32#{File::PATH_SEPARATOR}c:\\windows"
      Puppet::Util.withenv( {"PATH" => path }, :windows ) do
        Puppet.settings[:path] = "none" # this causes it to ignore the setting
        expect(ENV["PATH"]).to eq(path)
      end
    end

    it "path should support UTF8 characters" do
      path = "c:\\windows\\system32#{File::PATH_SEPARATOR}c:\\windows#{File::PATH_SEPARATOR}C:\\" + rune_utf8
      Puppet::Util.withenv( {"PATH" => path }, :windows) do
        Puppet.settings[:path] = "none" # this causes it to ignore the setting

        envhash = Puppet::Util::Windows::Process.get_environment_strings
        expect(envhash['Path']).to eq(path)
      end
    end
  end

  it "should default to pson for the preferred serialization format" do
    expect(Puppet.settings.value(:preferred_serialization_format)).to eq("pson")
  end

  it "should have a setting for determining the configuration version and should default to an empty string" do
    expect(Puppet.settings[:config_version]).to eq("")
  end

  describe "when enabling reports" do
    it "should use the default server value when report server is unspecified" do
      Puppet.settings[:server] = "server"
      expect(Puppet.settings[:report_server]).to eq("server")
    end

    it "should use the default masterport value when report port is unspecified" do
      Puppet.settings[:masterport] = "1234"
      expect(Puppet.settings[:report_port]).to eq("1234")
    end

    it "should use report_port when set" do
      Puppet.settings[:masterport] = "1234"
      Puppet.settings[:report_port] = "5678"
      expect(Puppet.settings[:report_port]).to eq("5678")
    end
  end

  it "should have a :caname setting that defaults to the cert name" do
    Puppet.settings[:certname] = "foo"
    expect(Puppet.settings[:ca_name]).to eq("Puppet CA: foo")
  end

  it "should have a 'prerun_command' that defaults to the empty string" do
    expect(Puppet.settings[:prerun_command]).to eq("")
  end

  it "should have a 'postrun_command' that defaults to the empty string" do
    expect(Puppet.settings[:postrun_command]).to eq("")
  end

  it "should have a 'certificate_revocation' setting that defaults to true" do
    expect(Puppet.settings[:certificate_revocation]).to be_truthy
  end

  describe "reportdir" do
    subject { Puppet.settings[:reportdir] }
    it { is_expected.to eq("#{Puppet[:vardir]}/reports") }
  end

  describe "reporturl" do
    subject { Puppet.settings[:reporturl] }
    it { is_expected.to eq("http://localhost:3000/reports/upload") }
  end

  describe "when configuring color" do
    subject { Puppet.settings[:color] }
    it { is_expected.to eq("ansi") }
  end

  describe "daemonize" do
    it "should default to true", :unless => Puppet.features.microsoft_windows? do
      expect(Puppet.settings[:daemonize]).to eq(true)
    end

    describe "on Windows", :if => Puppet.features.microsoft_windows? do
      it "should default to false" do
        expect(Puppet.settings[:daemonize]).to eq(false)
      end

      it "should raise an error if set to true" do
        expect { Puppet.settings[:daemonize] = true }.to raise_error(/Cannot daemonize on Windows/)
      end
    end
  end

  describe "diff" do
    it "should default to 'diff' on POSIX", :unless => Puppet.features.microsoft_windows? do
      expect(Puppet.settings[:diff]).to eq('diff')
    end

    it "should default to '' on Windows", :if => Puppet.features.microsoft_windows? do
      expect(Puppet.settings[:diff]).to eq('')
    end
  end

  describe "when configuring hiera" do
    it "should have a hiera_config setting" do
      expect(Puppet.settings[:hiera_config]).not_to be_nil
    end
  end

  describe "when configuring the data_binding terminus" do
    it "should have a data_binding_terminus setting" do
      expect(Puppet.settings[:data_binding_terminus]).not_to be_nil
    end

    it "should be set to hiera by default" do
      expect(Puppet.settings[:data_binding_terminus]).to eq(:hiera)
    end
  end

  describe "agent_catalog_run_lockfile" do
    it "(#2888) is not a file setting so it is absent from the Settings catalog" do
      expect(Puppet.settings.setting(:agent_catalog_run_lockfile)).not_to be_a_kind_of Puppet::Settings::FileSetting
      expect(Puppet.settings.setting(:agent_catalog_run_lockfile)).to be_a Puppet::Settings::StringSetting
    end
  end
end
