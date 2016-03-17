#! /usr/bin/env ruby
require 'spec_helper'

provider_class = Puppet::Type.type(:package).provider(:rpm)

describe provider_class do

  let (:packages) do
    <<-RPM_OUTPUT
    cracklib-dicts 0 2.8.9 3.3 x86_64
    basesystem 0 8.0 5.1.1.el5.centos noarch
    chkconfig 0 1.3.30.2 2.el5 x86_64
    myresource 0 1.2.3.4 5.el4 noarch
    mysummaryless 0 1.2.3.4 5.el4 noarch
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
    provider = provider_class.new
    provider.resource = resource
    provider
  end

  let(:nevra_format) { %Q{%{NAME} %|EPOCH?{%{EPOCH}}:{0}| %{VERSION} %{RELEASE} %{ARCH}\\n} }
  let(:execute_options) do
    {:failonfail => true, :combine => true, :custom_environment => {}}
  end
  let(:rpm_version) { "RPM version 5.0.0\n" }

  before(:each) do
    Puppet::Util.stubs(:which).with("rpm").returns("/bin/rpm")
    provider_class.stubs(:which).with("rpm").returns("/bin/rpm")
    provider_class.instance_variable_set("@current_version", nil)
    Puppet::Type::Package::ProviderRpm.expects(:execute).with(["/bin/rpm", "--version"]).returns(rpm_version).at_most_once
    Puppet::Util::Execution.expects(:execute).with(["/bin/rpm", "--version"], execute_options).returns(rpm_version).at_most_once
  end

  describe 'provider features' do
    it { should be_versionable }
    it { should be_install_options }
    it { should be_uninstall_options }
    it { should be_virtual_packages }
  end

  describe "self.instances" do
    describe "with a modern version of RPM" do
      it "includes all the modern flags" do
        Puppet::Util::Execution.expects(:execpipe).with("/bin/rpm -qa --nosignature --nodigest --qf '#{nevra_format}'").yields(packages)

        installed_packages = provider_class.instances
      end
    end

    describe "with a version of RPM < 4.1" do
      let(:rpm_version) { "RPM version 4.0.2\n" }
      it "excludes the --nosignature flag" do
        Puppet::Util::Execution.expects(:execpipe).with("/bin/rpm -qa  --nodigest --qf '#{nevra_format}'").yields(packages)

        installed_packages = provider_class.instances
      end
    end

    describe "with a version of RPM < 4.0.2" do
      let(:rpm_version) { "RPM version 3.0.5\n" }
      it "excludes the --nodigest flag" do
        Puppet::Util::Execution.expects(:execpipe).with("/bin/rpm -qa   --qf '#{nevra_format}'").yields(packages)

        installed_packages = provider_class.instances
      end
    end

    it "returns an array of packages" do
      Puppet::Util::Execution.expects(:execpipe).with("/bin/rpm -qa --nosignature --nodigest --qf '#{nevra_format}'").yields(packages)

      installed_packages = provider_class.instances

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
      expect(installed_packages.last.properties).to eq(
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
        Puppet::Util::Execution.expects(:execute).with(["/bin/rpm", ["-i"], '/path/to/package'], execute_options)
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
        Puppet::Util::Execution.expects(:execute).with(["/bin/rpm", ["-i", "-D", "--test=value", "-Q"], '/path/to/package'], execute_options)
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
         Puppet::Util::Execution.expects(:execute).with(["/bin/rpm", ["-U", "--oldpackage"], '/path/to/package'], execute_options)
         provider.install
      end
    end
  end

  describe "#latest" do
    it "retrieves version string after querying rpm for version from source file" do
      resource.expects(:[]).with(:source).returns('source-string')
      Puppet::Util::Execution.expects(:execfail).with(["/bin/rpm", "-q", "--qf", nevra_format, "-p", "source-string"], Puppet::Error).returns("myresource 0 1.2.3.4 5.el4 noarch\n")
      expect(provider.latest).to eq("1.2.3.4-5.el4")
    end
  end

  describe "#uninstall" do
    let(:resource) do
      Puppet::Type.type(:package).new(
        :name     => 'myresource',
        :ensure   => :installed
      )
    end

    describe "on a modern RPM" do
      before(:each) do
        Puppet::Util::Execution.expects(:execute).with(["/bin/rpm", "-q", "myresource", '--nosignature', '--nodigest', "--qf", nevra_format], execute_options).returns("myresource 0 1.2.3.4 5.el4 noarch\n")
      end

      let(:rpm_version) { "RPM version 4.10.0\n" }

      it "includes the architecture in the package name" do
        Puppet::Util::Execution.expects(:execute).with(["/bin/rpm", ["-e"], 'myresource-1.2.3.4-5.el4.noarch'], execute_options).returns('').at_most_once
        provider.uninstall
      end
    end

    describe "on an ancient RPM" do
      before(:each) do
        Puppet::Util::Execution.expects(:execute).with(["/bin/rpm", "-q", "myresource", '', '', '--qf', nevra_format], execute_options).returns("myresource 0 1.2.3.4 5.el4 noarch\n")
      end

      let(:rpm_version) { "RPM version 3.0.6\n" }

      it "excludes the architecture from the package name" do
        Puppet::Util::Execution.expects(:execute).with(["/bin/rpm", ["-e"], 'myresource-1.2.3.4-5.el4'], execute_options).returns('').at_most_once
        provider.uninstall
      end
    end

    describe "when uninstalled with options" do
      before(:each) do
        Puppet::Util::Execution.expects(:execute).with(["/bin/rpm", "-q", "myresource", '--nosignature', '--nodigest', "--qf", nevra_format], execute_options).returns("myresource 0 1.2.3.4 5.el4 noarch\n")
      end

      let(:resource) do
        Puppet::Type.type(:package).new(
          :name              => resource_name,
          :ensure            => :absent,
          :provider          => 'rpm',
          :uninstall_options => ['--nodeps']
        )
      end

      it "includes the options" do
        Puppet::Util::Execution.expects(:execute).with(["/bin/rpm", ["-e", "--nodeps"], 'myresource-1.2.3.4-5.el4.noarch'], execute_options)
        provider.uninstall
      end
    end
  end

  describe "parsing" do
    def parser_test(rpm_output_string, gold_hash, number_of_debug_logs = 0)
      Puppet.expects(:debug).times(number_of_debug_logs)
      Puppet::Util::Execution.expects(:execute).with(["/bin/rpm", "-q", resource_name, "--nosignature", "--nodigest", "--qf", nevra_format], execute_options).returns(rpm_output_string)
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
        :ensure => 'version-release',
      }
    end
    let(:line) { 'name epoch version release arch' }

    ['name', 'epoch', 'version', 'release', 'arch'].each do |field|

      it "still parses if #{field} is replaced by delimiter" do
        parser_test(
          line.gsub(field, delimiter),
          package_hash.merge(
            field.to_sym => delimiter,
            :ensure => 'version-release'.gsub(field, delimiter)
          )
        )
      end

    end

    it "does not fail if line is unparseable, but issues a debug log" do
      parser_test('bad data', {}, 1)
    end

    it "does not log or fail if rpm returns package not found" do
      Puppet.expects(:debug).never
      expected_args = ["/bin/rpm", "-q", resource_name, "--nosignature", "--nodigest", "--qf", nevra_format]
      Puppet::Util::Execution.expects(:execute).with(expected_args, execute_options).raises Puppet::ExecutionFailure.new("package #{resource_name} is not installed")
      expect(provider.query).to be_nil
    end

    it "parses virtual package" do
      provider.resource[:allow_virtual] = true
      expected_args = ["/bin/rpm", "-q", resource_name, "--nosignature", "--nodigest", "--qf", nevra_format]
      Puppet::Util::Execution.expects(:execute).with(expected_args, execute_options).raises Puppet::ExecutionFailure.new("package #{resource_name} is not installed")
      Puppet::Util::Execution.expects(:execute).with(expected_args + ["--whatprovides"], execute_options).returns "myresource 0 1.2.3.4 5.el4 noarch\n"
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
          provider_class.stubs(:current_version).returns(version)
          expect(provider_class.nodigest).to eq(expected)
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
          provider_class.stubs(:current_version).returns(version)
          expect(provider_class.nosignature).to eq(expected)
        end
      end
    end
  end
end
