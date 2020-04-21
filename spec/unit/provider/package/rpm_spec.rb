require 'spec_helper'

describe Puppet::Type.type(:package).provider(:rpm) do
  let (:packages) do
    <<-RPM_OUTPUT
    'cracklib-dicts 0 2.8.9 3.3 x86_64
    basesystem 0 8.0 5.1.1.el5.centos noarch
    chkconfig 0 1.3.30.2 2.el5 x86_64
    myresource 0 1.2.3.4 5.el4 noarch
    mysummaryless 0 1.2.3.4 5.el4 noarch
    tomcat 1 1.2.3.4 5.el4 x86_64
    kernel 1 1.2.3.4 5.el4 x86_64
    kernel 1 1.2.3.6 5.el4 x86_64
    '
    RPM_OUTPUT
  end

  let(:resource_name) { 'myresource' }
  let(:resource) do
    Puppet::Type.type(:package).new(
      :name     => resource_name,
      :ensure   => :installed,
      :provider => 'rpm'
    )
  end

  let(:provider) do
    provider = subject()
    provider.resource = resource
    provider
  end

  let(:nevra_format) { %Q{%{NAME} %|EPOCH?{%{EPOCH}}:{0}| %{VERSION} %{RELEASE} %{ARCH}\\n} }
  let(:execute_options) do
    {:failonfail => true, :combine => true, :custom_environment => {}}
  end
  let(:rpm_version) { "RPM version 5.0.0\n" }

  before(:each) do
    allow(Puppet::Util).to receive(:which).with("rpm").and_return("/bin/rpm")
    allow(described_class).to receive(:which).with("rpm").and_return("/bin/rpm")
    described_class.instance_variable_set("@current_version", nil)
    expect(Puppet::Type::Package::ProviderRpm).to receive(:execute)
      .with(["/bin/rpm", "--version"])
      .and_return(rpm_version).at_most(:once)
    expect(Puppet::Util::Execution).to receive(:execute)
      .with(["/bin/rpm", "--version"], execute_options)
      .and_return(Puppet::Util::Execution::ProcessOutput.new(rpm_version, 0)).at_most(:once)
  end

  describe 'provider features' do
    it { is_expected.to be_versionable }
    it { is_expected.to be_install_options }
    it { is_expected.to be_uninstall_options }
    it { is_expected.to be_virtual_packages }
  end

  describe "self.instances" do
    describe "with a modern version of RPM" do
      it "includes all the modern flags" do
        expect(Puppet::Util::Execution).to receive(:execpipe)
          .with("/bin/rpm -qa --nosignature --nodigest --qf '#{nevra_format}' | sort")
          .and_yield(packages)

        described_class.instances
      end
    end

    describe "with a version of RPM < 4.1" do
      let(:rpm_version) { "RPM version 4.0.2\n" }

      it "excludes the --nosignature flag" do
        expect(Puppet::Util::Execution).to receive(:execpipe)
          .with("/bin/rpm -qa  --nodigest --qf '#{nevra_format}' | sort")
          .and_yield(packages)

        described_class.instances
      end
    end

    describe "with a version of RPM < 4.0.2" do
      let(:rpm_version) { "RPM version 3.0.5\n" }

      it "excludes the --nodigest flag" do
        expect(Puppet::Util::Execution).to receive(:execpipe)
        .with("/bin/rpm -qa   --qf '#{nevra_format}' | sort")
        .and_yield(packages)

        described_class.instances
      end
    end

    it "returns an array of packages" do
      expect(Puppet::Util::Execution).to receive(:execpipe)
        .with("/bin/rpm -qa --nosignature --nodigest --qf '#{nevra_format}' | sort")
        .and_yield(packages)

      installed_packages = described_class.instances

      expect(installed_packages[0].properties).to eq(
        {
          :provider => :rpm,
          :name => "cracklib-dicts",
          :epoch => "0",
          :version => "2.8.9",
          :release => "3.3",
          :arch => "x86_64",
          :ensure => "2.8.9-3.3",
        }
      )
      expect(installed_packages[1].properties).to eq(
        {
          :provider => :rpm,
          :name => "basesystem",
          :epoch => "0",
          :version => "8.0",
          :release => "5.1.1.el5.centos",
          :arch => "noarch",
          :ensure => "8.0-5.1.1.el5.centos",
        }
      )
      expect(installed_packages[2].properties).to eq(
        {
          :provider => :rpm,
          :name => "chkconfig",
          :epoch => "0",
          :version => "1.3.30.2",
          :release => "2.el5",
          :arch => "x86_64",
          :ensure => "1.3.30.2-2.el5",
        }
      )
      expect(installed_packages[3].properties).to eq(
        {
          :provider => :rpm,
          :name => "myresource",
          :epoch => "0",
          :version => "1.2.3.4",
          :release => "5.el4",
          :arch => "noarch",
          :ensure => "1.2.3.4-5.el4",
        }
      )
      expect(installed_packages[4].properties).to eq(
        {
          :provider    => :rpm,
          :name        => "mysummaryless",
          :epoch       => "0",
          :version     => "1.2.3.4",
          :release     => "5.el4",
          :arch        => "noarch",
          :ensure      => "1.2.3.4-5.el4",
        }
      )
      expect(installed_packages[5].properties).to eq(
        {
          :provider    => :rpm,
          :name        => "tomcat",
          :epoch       => "1",
          :version     => "1.2.3.4",
          :release     => "5.el4",
          :arch        => "x86_64",
          :ensure      => "1:1.2.3.4-5.el4",
        }
      )
      expect(installed_packages[6].properties).to eq(
        {
          :provider    => :rpm,
          :name        => "kernel",
          :epoch       => "1",
          :version     => "1.2.3.4",
          :release     => "5.el4",
          :arch        => "x86_64",
          :ensure      => "1:1.2.3.4-5.el4; 1:1.2.3.6-5.el4",
        }
      )
    end
  end

  describe "#install" do
    let(:resource) do
      Puppet::Type.type(:package).new(
        :name     => 'myresource',
        :ensure   => :installed,
        :source   => '/path/to/package'
      )
    end

    describe "when not already installed" do
      it "only includes the '-i' flag" do
        expect(Puppet::Util::Execution).to receive(:execute)
          .with(["/bin/rpm", ["-i"], '/path/to/package'], execute_options)
        provider.install
      end
    end

    describe "when installed with options" do
      let(:resource) do
        Puppet::Type.type(:package).new(
          :name            => resource_name,
          :ensure          => :installed,
          :provider        => 'rpm',
          :source          => '/path/to/package',
          :install_options => ['-D', {'--test' => 'value'}, '-Q']
        )
      end

      it "includes the options" do
        expect(Puppet::Util::Execution).to receive(:execute)
          .with(["/bin/rpm", ["-i", "-D", "--test=value", "-Q"], '/path/to/package'], execute_options)
        provider.install
      end
    end

    describe "when an older version is installed" do
      before(:each) do
        # Force the provider to think a version of the package is already installed
        # This is real hacky. I'm sorry.  --jeffweiss 25 Jan 2013
        provider.instance_variable_get('@property_hash')[:ensure] = '1.2.3.3'
      end

      it "includes the '-U --oldpackage' flags" do
         expect(Puppet::Util::Execution).to receive(:execute)
           .with(["/bin/rpm", ["-U", "--oldpackage"], '/path/to/package'], execute_options)
         provider.install
      end
    end
  end

  describe "#latest" do
    it "retrieves version string after querying rpm for version from source file" do
      expect(resource).to receive(:[]).with(:source).and_return('source-string')
      expect(Puppet::Util::Execution).to receive(:execute)
        .with(["/bin/rpm", "-q", "--qf", "#{nevra_format}", "-p", "source-string"])
        .and_return(Puppet::Util::Execution::ProcessOutput.new("myresource 0 1.2.3.4 5.el4 noarch\n", 0))
      expect(provider.latest).to eq("1.2.3.4-5.el4")
    end

    it "raises an error if the rpm command fails" do
      expect(resource).to receive(:[]).with(:source).and_return('source-string')
      expect(Puppet::Util::Execution).to receive(:execute)
        .with(["/bin/rpm", "-q", "--qf", "#{nevra_format}", "-p", "source-string"])
        .and_raise(Puppet::ExecutionFailure, 'rpm command failed')

      expect {
        provider.latest
      }.to raise_error(Puppet::Error, 'rpm command failed')
    end
  end

  describe "#uninstall" do
    let(:resource) do
      Puppet::Type.type(:package).new(
        :name   => resource_name,
        :ensure => :installed
      )
    end

    describe "on an ancient RPM" do
      let(:rpm_version) { "RPM version 3.0.6\n" }

      before(:each) do
        expect(Puppet::Util::Execution).to receive(:execute)
          .with(["/bin/rpm", "-q", resource_name, '', '', '--qf', "#{nevra_format}"], execute_options)
          .and_return(Puppet::Util::Execution::ProcessOutput.new("#{resource_name} 0 1.2.3.4 5.el4 noarch\n", 0))
      end

      it "excludes the architecture from the package name" do
        expect(Puppet::Util::Execution).to receive(:execute)
          .with(["/bin/rpm", ["-e"], resource_name], execute_options)
          .and_return(Puppet::Util::Execution::ProcessOutput.new('', 0)).at_most(:once)
        provider.uninstall
      end
    end

    describe "on a modern RPM" do
      let(:rpm_version) { "RPM version 4.10.0\n" }


      before(:each) do
        expect(Puppet::Util::Execution).to receive(:execute)
          .with(["/bin/rpm", "-q", resource_name, '--nosignature', '--nodigest', "--qf", "#{nevra_format}"], execute_options)
          .and_return(Puppet::Util::Execution::ProcessOutput.new("#{resource_name} 0 1.2.3.4 5.el4 noarch\n", 0))
      end

      it "excludes the architecture from the package name" do
        expect(Puppet::Util::Execution).to receive(:execute)
          .with(["/bin/rpm", ["-e"], resource_name], execute_options)
          .and_return(Puppet::Util::Execution::ProcessOutput.new('', 0)).at_most(:once)
        provider.uninstall
      end
    end

    describe "on a modern RPM when architecture is specified" do
      let(:rpm_version) { "RPM version 4.10.0\n" }

      let(:resource) do
        Puppet::Type.type(:package).new(
          :name   => "#{resource_name}.noarch",
          :ensure => :absent,
        )
      end

      before(:each) do
        expect(Puppet::Util::Execution).to receive(:execute)
          .with(["/bin/rpm", "-q", "#{resource_name}.noarch", '--nosignature', '--nodigest', "--qf", "#{nevra_format}"], execute_options)
          .and_return(Puppet::Util::Execution::ProcessOutput.new("#{resource_name} 0 1.2.3.4 5.el4 noarch\n", 0))
      end

      it "includes the architecture in the package name" do
        expect(Puppet::Util::Execution).to receive(:execute)
          .with(["/bin/rpm", ["-e"], "#{resource_name}.noarch"], execute_options)
          .and_return(Puppet::Util::Execution::ProcessOutput.new('', 0)).at_most(:once)
        provider.uninstall
      end
    end

    describe "when version and release are specified" do
      let(:resource) do
        Puppet::Type.type(:package).new(
          :name   => "#{resource_name}-1.2.3.4-5.el4",
          :ensure => :absent,
        )
      end

      before(:each) do
        expect(Puppet::Util::Execution).to receive(:execute)
          .with(["/bin/rpm", "-q", "#{resource_name}-1.2.3.4-5.el4", '--nosignature', '--nodigest', "--qf", "#{nevra_format}"], execute_options)
          .and_return(Puppet::Util::Execution::ProcessOutput.new("#{resource_name} 0 1.2.3.4 5.el4 noarch\n", 0))
      end

      it "includes the version and release in the package name" do
        expect(Puppet::Util::Execution).to receive(:execute)
          .with(["/bin/rpm", ["-e"], "#{resource_name}-1.2.3.4-5.el4"], execute_options)
          .and_return(Puppet::Util::Execution::ProcessOutput.new('', 0)).at_most(:once)
        provider.uninstall
      end
    end

    describe "when only version is specified" do
      let(:resource) do
        Puppet::Type.type(:package).new(
          :name   => "#{resource_name}-1.2.3.4",
          :ensure => :absent,
        )
      end

      before(:each) do
        expect(Puppet::Util::Execution).to receive(:execute)
          .with(["/bin/rpm", "-q", "#{resource_name}-1.2.3.4", '--nosignature', '--nodigest', "--qf", "#{nevra_format}"], execute_options)
          .and_return(Puppet::Util::Execution::ProcessOutput.new("#{resource_name} 0 1.2.3.4 5.el4 noarch\n", 0))
      end

      it "includes the version in the package name" do
        expect(Puppet::Util::Execution).to receive(:execute)
          .with(["/bin/rpm", ["-e"], "#{resource_name}-1.2.3.4"], execute_options)
          .and_return(Puppet::Util::Execution::ProcessOutput.new('', 0)).at_most(:once)
        provider.uninstall
      end
    end

    describe "when uninstalled with options" do
      let(:resource) do
        Puppet::Type.type(:package).new(
          :name              => resource_name,
          :ensure            => :absent,
          :provider          => 'rpm',
          :uninstall_options => ['--nodeps']
        )
      end

      before(:each) do
        expect(Puppet::Util::Execution).to receive(:execute)
          .with(["/bin/rpm", "-q", resource_name, '--nosignature', '--nodigest', "--qf", "#{nevra_format}"], execute_options)
          .and_return(Puppet::Util::Execution::ProcessOutput.new("#{resource_name} 0 1.2.3.4 5.el4 noarch\n", 0))
      end

      it "includes the options" do
        expect(Puppet::Util::Execution).to receive(:execute)
          .with(["/bin/rpm", ["-e", "--nodeps"], resource_name], execute_options)
        provider.uninstall
      end
    end
  end

  describe "parsing" do
    def parser_test(rpm_output_string, gold_hash, number_of_debug_logs = 0)
      expect(Puppet).to receive(:debug).exactly(number_of_debug_logs).times()
      expect(Puppet::Util::Execution).to receive(:execute)
        .with(["/bin/rpm", "-q", resource_name, "--nosignature", "--nodigest", "--qf", "#{nevra_format}"], execute_options)
        .and_return(Puppet::Util::Execution::ProcessOutput.new(rpm_output_string, 0))
      expect(provider.query).to eq(gold_hash)
    end

    let(:resource_name) { 'name' }
    let('delimiter') { ':DESC:' }
    let(:package_hash) do
      {
        :name => 'name',
        :epoch => 'epoch',
        :version => 'version',
        :release => 'release',
        :arch => 'arch',
        :provider => :rpm,
        :ensure => 'epoch:version-release',
      }
    end
    let(:line) { 'name epoch version release arch' }

    ['name', 'epoch', 'version', 'release', 'arch'].each do |field|
      it "still parses if #{field} is replaced by delimiter" do
        parser_test(
          line.gsub(field, delimiter),
          package_hash.merge(
            field.to_sym => delimiter,
            :ensure => 'epoch:version-release'.gsub(field, delimiter)
          )
        )
      end
    end

    it "does not fail if line is unparseable, but issues a debug log" do
      parser_test('bad data', {}, 1)
    end

    describe "when the package is not found" do
      before do
        expect(Puppet).not_to receive(:debug)
        expected_args = ["/bin/rpm", "-q", resource_name, "--nosignature", "--nodigest", "--qf", "#{nevra_format}"]
        expect(Puppet::Util::Execution).to receive(:execute)
          .with(expected_args, execute_options)
          .and_raise(Puppet::ExecutionFailure.new("package #{resource_name} is not installed"))
      end

      it "does not log or fail if allow_virtual is false" do
        resource[:allow_virtual] = false
        expect(provider.query).to be_nil
      end

      it "does not log or fail if allow_virtual is true" do
        resource[:allow_virtual] = true
        expected_args = ['/bin/rpm', '-q', resource_name, '--nosignature', '--nodigest', '--qf', "#{nevra_format}", '--whatprovides']
        expect(Puppet::Util::Execution).to receive(:execute)
          .with(expected_args, execute_options)
          .and_raise(Puppet::ExecutionFailure.new("package #{resource_name} is not provided"))
        expect(provider.query).to be_nil
      end
    end

    it "parses virtual package" do
      provider.resource[:allow_virtual] = true
      expected_args = ["/bin/rpm", "-q", resource_name, "--nosignature", "--nodigest", "--qf", "#{nevra_format}"]
      expect(Puppet::Util::Execution).to receive(:execute)
        .with(expected_args, execute_options)
        .and_raise(Puppet::ExecutionFailure.new("package #{resource_name} is not installed"))
      expect(Puppet::Util::Execution).to receive(:execute)
        .with(expected_args + ["--whatprovides"], execute_options)
        .and_return(Puppet::Util::Execution::ProcessOutput.new("myresource 0 1.2.3.4 5.el4 noarch\n", 0))
      expect(provider.query).to eq({
        :name     => "myresource",
        :epoch    => "0",
        :version  => "1.2.3.4",
        :release  => "5.el4",
        :arch     => "noarch",
        :provider => :rpm,
        :ensure   => "1.2.3.4-5.el4"
      })
    end
  end

  describe "#install_options" do
    it "returns nil by default" do
      expect(provider.install_options).to eq(nil)
    end

    it "returns install_options when set" do
      provider.resource[:install_options] = ['-n']
      expect(provider.install_options).to eq(['-n'])
    end

    it "returns multiple install_options when set" do
      provider.resource[:install_options] = ['-L', '/opt/puppet']
      expect(provider.install_options).to eq(['-L', '/opt/puppet'])
    end

    it 'returns install_options when set as hash' do
      provider.resource[:install_options] = [{ '-Darch' => 'vax' }]
      expect(provider.install_options).to eq(['-Darch=vax'])
    end

    it 'returns install_options when an array with hashes' do
      provider.resource[:install_options] = [ '-L', { '-Darch' => 'vax' }]
      expect(provider.install_options).to eq(['-L', '-Darch=vax'])
    end
  end

  describe "#uninstall_options" do
    it "returns nil by default" do
      expect(provider.uninstall_options).to eq(nil)
    end

    it "returns uninstall_options when set" do
      provider.resource[:uninstall_options] = ['-n']
      expect(provider.uninstall_options).to eq(['-n'])
    end

    it "returns multiple uninstall_options when set" do
      provider.resource[:uninstall_options] = ['-L', '/opt/puppet']
      expect(provider.uninstall_options).to eq(['-L', '/opt/puppet'])
    end

    it 'returns uninstall_options when set as hash' do
      provider.resource[:uninstall_options] = [{ '-Darch' => 'vax' }]
      expect(provider.uninstall_options).to eq(['-Darch=vax'])
    end
    it 'returns uninstall_options when an array with hashes' do
      provider.resource[:uninstall_options] = [ '-L', { '-Darch' => 'vax' }]
      expect(provider.uninstall_options).to eq(['-L', '-Darch=vax'])
    end
  end

  describe ".nodigest" do
    { '4.0'   => nil,
      '4.0.1' => nil,
      '4.0.2' => '--nodigest',
      '4.0.3' => '--nodigest',
      '4.1'   => '--nodigest',
      '5'     => '--nodigest',
    }.each do |version, expected|
      describe "when current version is #{version}" do
        it "returns #{expected.inspect}" do
          allow(described_class).to receive(:current_version).and_return(version)
          expect(described_class.nodigest).to eq(expected)
        end
      end
    end
  end

  describe ".nosignature" do
    { '4.0.3' => nil,
      '4.1'   => '--nosignature',
      '4.1.1' => '--nosignature',
      '4.2'   => '--nosignature',
      '5'     => '--nosignature',
    }.each do |version, expected|
      describe "when current version is #{version}" do
        it "returns #{expected.inspect}" do
          allow(described_class).to receive(:current_version).and_return(version)
          expect(described_class.nosignature).to eq(expected)
        end
      end
    end
  end

  describe 'insync?' do
    context 'for multiple versions' do
      let(:is) { '1:1.2.3.4-5.el4; 1:5.6.7.8-5.el4' }
      it 'returns true if there is match and feature is enabled' do
        resource[:install_only] = true
        resource[:ensure] = '1:1.2.3.4-5.el4'
        expect(provider).to be_insync(is)
      end
      it 'returns false if there is match and feature is not enabled' do
        resource[:ensure] = '1:1.2.3.4-5.el4'
        expect(provider).to_not be_insync(is)
      end
      it 'returns false if no match and feature is enabled' do
        resource[:install_only] = true
        resource[:ensure] = '1:1.2.3.6-5.el4'
        expect(provider).to_not be_insync(is)
      end
      it 'returns false if no match and feature is not enabled' do
        resource[:ensure] = '1:1.2.3.6-5.el4'
        expect(provider).to_not be_insync(is)
      end
    end
    context 'for simple versions' do
      let(:is) { '1:1.2.3.4-5.el4' }
      it 'returns true if there is match and feature is enabled' do
        resource[:install_only] = true
        resource[:ensure] = '1:1.2.3.4-5.el4'
        expect(provider).to be_insync(is)
      end
      it 'returns true if there is match and feature is not enabled' do
        resource[:ensure] = '1:1.2.3.4-5.el4'
        expect(provider).to be_insync(is)
      end
      it 'returns false if no match and feature is enabled' do
        resource[:install_only] = true
        resource[:ensure] = '1:1.2.3.6-5.el4'
        expect(provider).to_not be_insync(is)
      end
      it 'returns false if no match and feature is not enabled' do
        resource[:ensure] = '1:1.2.3.6-5.el4'
        expect(provider).to_not be_insync(is)
      end
    end
  end

  describe 'rpm multiversion to hash' do
    it 'should return empty hash for empty imput' do
      package_hash = described_class.nevra_to_multiversion_hash('')
      expect(package_hash).to eq({})
    end

    it 'should return package hash for one package input' do
      package_list = <<-RPM_OUTPUT
kernel-devel 1 1.2.3.4 5.el4 x86_64
RPM_OUTPUT
      package_hash = described_class.nevra_to_multiversion_hash(package_list)
      expect(package_hash).to eq(
        {
          :arch => "x86_64",
          :ensure => "1:1.2.3.4-5.el4",
          :epoch => "1",
          :name => "kernel-devel",
          :provider => :rpm,
          :release => "5.el4",
          :version => "1.2.3.4",
        }
      )
    end

    it 'should return package hash with versions concatenated in ensure for two package input' do
      package_list = <<-RPM_OUTPUT
kernel-devel 1 1.2.3.4 5.el4 x86_64
kernel-devel 1 5.6.7.8 5.el4 x86_64
RPM_OUTPUT
      package_hash = described_class.nevra_to_multiversion_hash(package_list)
      expect(package_hash).to eq(
        {
          :arch => "x86_64",
          :ensure => "1:1.2.3.4-5.el4; 1:5.6.7.8-5.el4",
          :epoch => "1",
          :name => "kernel-devel",
          :provider => :rpm,
          :release => "5.el4",
          :version => "1.2.3.4",
        }
      )
    end

    it 'should return list of packages for one multiversion and one package input' do
      package_list = <<-RPM_OUTPUT
kernel-devel 1 1.2.3.4 5.el4 x86_64
kernel-devel 1 5.6.7.8 5.el4 x86_64
basesystem 0 8.0 5.1.1.el5.centos noarch
RPM_OUTPUT
      package_hash = described_class.nevra_to_multiversion_hash(package_list)
      expect(package_hash).to eq(
        [
          {
            :arch => "x86_64",
            :ensure => "1:1.2.3.4-5.el4; 1:5.6.7.8-5.el4",
            :epoch => "1",
            :name => "kernel-devel",
            :provider => :rpm,
            :release => "5.el4",
            :version => "1.2.3.4",
          },
          {
            :provider => :rpm,
            :name => "basesystem",
            :epoch => "0",
            :version => "8.0",
            :release => "5.1.1.el5.centos",
            :arch => "noarch",
            :ensure => "8.0-5.1.1.el5.centos",
          }
        ]
      )
    end
  end
end
