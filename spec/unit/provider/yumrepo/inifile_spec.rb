require 'spec_helper'

describe Puppet::Type.type(:yumrepo).provider(:inifile) do

  let(:virtual_inifile) { stub('virtual inifile') }

  before :each do
    described_class.stubs(:virtual_inifile).returns(virtual_inifile)
  end

  describe 'self.instances' do
    let(:updates_section) do
      stub('inifile updates section',
           :name => 'updates',
           :entries => {'name' => 'updates', 'enabled' => '1', 'descr' => 'test updates'})
    end

    it 'finds any existing sections' do
      virtual_inifile.expects(:each_section).yields(updates_section)

      providers = described_class.instances
      providers.should have(1).items
      providers[0].name.should == 'updates'
      providers[0].enabled.should == '1'
    end
  end

  describe "methods used by ensurable" do

    let(:type) do
      Puppet::Type.type(:yumrepo).new(
        :name     => 'puppetlabs-products',
        :ensure   => :present,
        :baseurl  => 'http://yum.puppetlabs.com/el/6/products/$basearch',
        :descr    => 'Puppet Labs Products El 6 - $basearch',
        :enabled  => '1',
        :gpgcheck => '1',
        :gpgkey   => 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-puppetlabs'
      )
    end

    let(:provider) { type.provider }

    let(:puppetlabs_section) { stub('inifile puppetlabs section', :name => 'puppetlabs-products') }

    it "#create sets the yumrepo properties on the according section" do
      described_class.expects(:section).returns(puppetlabs_section)
      puppetlabs_section.expects(:[]=).with('baseurl', 'http://yum.puppetlabs.com/el/6/products/$basearch')
      puppetlabs_section.expects(:[]=).with('descr', 'Puppet Labs Products El 6 - $basearch')
      puppetlabs_section.expects(:[]=).with('enabled', '1')
      puppetlabs_section.expects(:[]=).with('gpgcheck', '1')
      puppetlabs_section.expects(:[]=).with('gpgkey', 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-puppetlabs')

      provider.create
    end

    it "#exists? checks if the repo has been marked as present" do
      described_class.stubs(:section).returns(stub(:[]= => nil))
      provider.create
      expect(provider).to be_exist
    end

    it "#destroy deletes the associated ini file section" do
      described_class.expects(:section).returns(puppetlabs_section)
      puppetlabs_section.expects(:destroy=).with(true)
      provider.destroy
    end
  end

  describe 'reposdir' do
    let(:defaults) { ['/etc/yum.repos.d', '/etc/yum/repos.d'] }

    before do
      Puppet::FileSystem.stubs(:exist?).with('/etc/yum.repos.d').returns(true)
      Puppet::FileSystem.stubs(:exist?).with('/etc/yum/repos.d').returns(true)
    end

    it "returns the default directories if yum.conf doesn't contain a `reposdir` entry" do
      described_class.stubs(:find_conf_value).with('reposdir', '/etc/yum.conf')
      described_class.reposdir('/etc/yum.conf').should == defaults
    end

    it "includes the directory specified by the yum.conf 'reposdir' entry when the directory is present" do
      Puppet::FileSystem.expects(:exist?).with("/etc/yum/extra.repos.d").returns(true)

      described_class.expects(:find_conf_value).with('reposdir', '/etc/yum.conf').returns "/etc/yum/extra.repos.d"
      described_class.reposdir('/etc/yum.conf').should include("/etc/yum/extra.repos.d")
    end

    it "doesn't the directory specified by the yum.conf 'reposdir' entry when the directory is absent" do
      Puppet::FileSystem.expects(:exist?).with("/etc/yum/extra.repos.d").returns(false)

      described_class.expects(:find_conf_value).with('reposdir', '/etc/yum.conf').returns "/etc/yum/extra.repos.d"
      described_class.reposdir('/etc/yum.conf').should_not include("/etc/yum/extra.repos.d")
    end

    it "raises an entry if none of the specified repo directories exist" do
      Puppet::FileSystem.unstub(:exist?)
      Puppet::FileSystem.stubs(:exist?).returns false

      described_class.stubs(:find_conf_value).with('reposdir', '/etc/yum.conf')
      expect { described_class.reposdir('/etc/yum.conf') }.to raise_error('No yum directories were found on the local filesystem')
    end
  end
end
