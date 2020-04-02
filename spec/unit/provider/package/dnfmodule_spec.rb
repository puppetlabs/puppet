require 'spec_helper'

describe Puppet::Type.type(:package).provider(:dnfmodule) do
  include PuppetSpec::Fixtures

  let(:dnf_version) do
    <<-DNF_OUTPUT
    4.0.9
      Installed: dnf-0:4.0.9.2-5.el8.noarch at Wed 29 May 2019 07:05:05 AM GMT
      Built    : Red Hat, Inc. <http://bugzilla.redhat.com/bugzilla> at Thu 14 Feb 2019 12:04:07 PM GMT

      Installed: rpm-0:4.14.2-9.el8.x86_64 at Wed 29 May 2019 07:04:33 AM GMT
      Built    : Red Hat, Inc. <http://bugzilla.redhat.com/bugzilla> at Thu 20 Dec 2018 01:30:03 PM GMT
    DNF_OUTPUT
  end

  let(:execute_options) do
    {:failonfail => true, :combine => true, :custom_environment => {}}
  end

  let(:packages) { File.read(my_fixture("dnf-module-list-enabled.txt")) }
  let(:dnf_path) { '/usr/bin/dnf' }

  before(:each) { allow(Puppet::Util).to receive(:which).with('/usr/bin/dnf').and_return(dnf_path) }

  it "should have lower specificity" do
    allow(Facter).to receive(:value).with(:osfamily).and_return(:redhat)
    allow(Facter).to receive(:value).with(:operatingsystem).and_return(:redhat)
    allow(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return('8')
    expect(described_class.specificity).to be < 200
  end

  describe "should be an opt-in provider" do
    Array(4..8).each do |ver|
      it "should not be default for redhat #{ver}" do
        allow(Facter).to receive(:value).with(:operatingsystem).and_return('redhat')
        allow(Facter).to receive(:value).with(:osfamily).and_return('redhat')
        allow(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return(ver.to_s)
        expect(described_class).not_to be_default
      end
    end
  end

  describe "handling dnf versions" do
    before(:each) do
      expect(Puppet::Type::Package::ProviderDnfmodule).to receive(:execute)
          .with(["/usr/bin/dnf", "--version"])
          .and_return(dnf_version).at_most(:once)
      expect(Puppet::Util::Execution).to receive(:execute)
          .with(["/usr/bin/dnf", "--version"], execute_options)
          .and_return(Puppet::Util::Execution::ProcessOutput.new(dnf_version, 0))
    end

    describe "with a supported dnf version" do
      it "correctly parses the version" do
        expect(described_class.current_version).to eq('4.0.9')
      end
    end

    describe "with an unsupported dnf version" do
      let(:dnf_version) do
        <<-DNF_OUTPUT
        2.7.5
          Installed: dnf-0:2.7.5-12.fc28.noarch at Mon 13 Aug 2018 11:05:27 PM GMT
          Built    : Fedora Project at Wed 18 Apr 2018 02:29:51 PM GMT

          Installed: rpm-0:4.14.1-7.fc28.x86_64 at Mon 13 Aug 2018 11:05:25 PM GMT
          Built    : Fedora Project at Mon 19 Feb 2018 09:29:01 AM GMT
        DNF_OUTPUT
      end

      before(:each) { described_class.instance_variable_set("@current_version", nil) }

      it "correctly parses the version" do
        expect(described_class.current_version).to eq('2.7.5')
      end

      it "raises an error when attempting prefetch" do
        expect { described_class.prefetch('anything') }.to raise_error(Puppet::Error, "Modules are not supported on DNF versions lower than 3.0.1")
      end
    end
  end

  describe "when installing a module" do
    let(:name) { 'baz' }

    let(:resource) do
      Puppet::Type.type(:package).new(
        :name => name,
        :provider => 'dnfmodule',
      )
    end

    let(:provider) do
      provider = described_class.new
      provider.resource = resource
      provider
    end

    describe 'provider features' do
      it { is_expected.to be_versionable }
      it { is_expected.to be_installable }
      it { is_expected.to be_uninstallable }
    end

    context "when installing a new module" do
      before do
        provider.instance_variable_get('@property_hash')[:ensure] = :absent
      end

      it "should not reset the module stream when package is absent" do
        resource[:ensure] = :present
        expect(provider).not_to receive(:uninstall)
        expect(provider).to receive(:execute)
        provider.install
      end

      it "should not reset the module stream when package is purged" do
        provider.instance_variable_get('@property_hash')[:ensure] = :purged
        resource[:ensure] = :present
        expect(provider).not_to receive(:uninstall)
        expect(provider).to receive(:execute)
        provider.install
      end

      it "should just enable the module if it has no default profile" do
        dnf_exception = Puppet::ExecutionFailure.new("Error: Problems in request:\nmissing groups or modules: #{resource[:name]}")
        allow(provider).to receive(:execute).with(array_including('install')).and_raise(dnf_exception)
        resource[:ensure] = :present
        expect(provider).to receive(:execute).with(array_including('install')).ordered
        expect(provider).to receive(:execute).with(array_including('enable')).ordered
        provider.install
      end

      it "should just enable the module if enable_only = true" do
        resource[:ensure] = :present
        resource[:enable_only] = true
        expect(provider).to receive(:execute).with(array_including('enable'))
        expect(provider).not_to receive(:execute).with(array_including('install'))
        provider.install
      end

      it "should install the default stream and flavor" do
        resource[:ensure] = :present
        expect(provider).to receive(:execute).with(array_including('baz'))
        provider.install
      end

      it "should install a specific stream" do
        resource[:ensure] = '9.6'
        expect(provider).to receive(:execute).with(array_including('baz:9.6'))
        provider.install
      end

      it "should install a specific flavor" do
        resource[:ensure] = :present
        resource[:flavor] = 'minimal'
        expect(provider).to receive(:execute).with(array_including('baz/minimal'))
        provider.install
      end

      it "should install a specific flavor and stream" do
        resource[:ensure] = '9.6'
        resource[:flavor] = 'minimal'
        expect(provider).to receive(:execute).with(array_including('baz:9.6/minimal'))
        provider.install
      end
    end

    context "when ensuring a specific version on top of another stream" do
      before do
        provider.instance_variable_get('@property_hash')[:ensure] = '9.6'
      end

      it "should remove existing packages and reset the module stream before installing" do
        resource[:ensure] = '10'
        expect(provider).to receive(:execute).thrice.with(array_including(/remove|reset|install/))
        provider.install
      end
    end

    context "with an installed flavor" do
      before do
        provider.instance_variable_get('@property_hash')[:flavor] = 'minimal'
      end

      it "should remove existing packages and reset the module stream before installing another flavor" do
        resource[:flavor] = 'common'
        expect(provider).to receive(:execute).thrice.with(array_including(/remove|reset|install/))
        provider.flavor = resource[:flavor]
      end

      it "should not do anything if the flavor doesn't change" do
        resource[:flavor] = 'minimal'
        expect(provider).not_to receive(:execute)
        provider.flavor = resource[:flavor]
      end

      it "should return the existing flavor" do
        expect(provider.flavor).to eq('minimal')
      end
    end
  end

  context "parsing the output of module list --enabled" do
    before { allow(described_class).to receive(:command).with(:dnf).and_return(dnf_path) }

    it "returns an array of enabled modules" do
      allow(Puppet::Util::Execution).to receive(:execute)
        .with("/usr/bin/dnf module list --enabled -d 0 -e 1")
        .and_return(packages)

      enabled_packages = described_class.instances.map { |package| package.properties }
      expected_packages = [{name: "389-ds", ensure: "1.4", flavor: :absent, provider: :dnfmodule},
                           {name: "gimp", ensure: "2.8", flavor: "devel", provider: :dnfmodule},
                           {name: "mariadb", ensure: "10.3", flavor: "client", provider: :dnfmodule},
                           {name: "nodejs", ensure: "10", flavor: "minimal", provider: :dnfmodule},
                           {name: "perl", ensure: "5.26", flavor: "minimal", provider: :dnfmodule},
                           {name: "postgresql", ensure: "10", flavor: "server", provider: :dnfmodule},
                           {name: "ruby", ensure: "2.5", flavor: :absent, provider: :dnfmodule},
                           {name: "rust-toolset", ensure: "rhel8", flavor: "common", provider: :dnfmodule},
                           {name: "subversion", ensure: "1.10", flavor: "server", provider: :dnfmodule}]

      expect(enabled_packages).to eql(expected_packages)
    end
  end
end
