require 'spec_helper'
require 'puppet'

describe Puppet::Type.type(:yumrepo).provider(:inifile) do
  let(:yumrepo) {
    Puppet::Type.type(:yumrepo).new(
      :name     => 'puppetlabs-products',
      :ensure   => :present,
      :baseurl  => 'http://yum.puppetlabs.com/el/6/products/$basearch',
      :descr    => 'Puppet Labs Products El 6 - $basearch',
      :enabled  => '1',
      :gpgcheck => '1',
      :gpgkey   => 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-puppetlabs'
    )
  }
  let(:yumrepo_provider) { yumrepo.provider }
  let(:repo_file) { '
[updates]
name="updates"
enabled = 1
descr="test updates"
'
  }

  before :each do
    Dir.stubs(:glob).with('/etc/yum.repos.d/*.repo').returns(['/etc/yum.repos.d/test.repo'])
  end

  describe 'self.instances' do
    before :each do
      described_class.stubs(:reposdir).returns(['/etc/yum.repos.d'])
      File.expects(:file?).with('/etc/yum.repos.d/test.repo').returns(true)
      File.expects(:exist?).with(Pathname.new('/etc/yum.repos.d/test.repo')).returns(true)
      File.expects(:read).with('/etc/yum.repos.d/test.repo').returns(repo_file)
    end

    it 'finds the update repo' do
      providers = yumrepo_provider.class.instances
      providers.count.should == 1
      providers[0].name.should == 'updates'
      providers[0].enabled.should == '1'
    end
  end

  describe 'create' do
    it 'creates a yumrepo' do
      yumrepo_provider.section('puppetlabs-products').expects(:[]=).at_least(1)
      yumrepo_provider.create
    end
  end

  describe 'destroy' do
    it 'flags the section to be destroyed' do
      yumrepo_provider.section('puppetlabs-products').expects(:destroy=).with(true)
      yumrepo_provider.destroy
    end
  end

  describe 'exists?' do
    it 'checks if yumrepo exists' do
      described_class.stubs(:reposdir).returns(['/etc/yum.repos.d'])
      yumrepo_provider.ensure= :present
      yumrepo_provider.exists?.should be_true
   end
  end

  describe 'reposdir' do
    let(:defaults) { ['/etc/yum.repos.d', '/etc/yum/repos.d'] }
    let(:all) { ['/etc/yum.repos.d', '/etc/yum/repos.d', '/etc/yum/test'] }

    it 'returns defaults if no yum conf' do
      File.expects(:exists?).with('/etc/yum.conf').returns(false)

      described_class.reposdir('/etc/yum.conf').should == defaults
    end

    it 'returns defaults if yumconf has no reposdir' do
      File.expects(:exists?).with('/etc/yum.conf').returns(true)
      File.expects(:read).with('/etc/yum.conf').returns("[main]\ntest = /etc/yum/test")

      described_class.reposdir('/etc/yum.conf').should == defaults
    end

    it 'returns all directories if yum.conf contains reposdir' do
      File.expects(:exists?).with('/etc/yum.conf').returns(true)
      File.expects(:read).with('/etc/yum.conf').returns("[main]\nreposdir = /etc/yum/test")

      described_class.reposdir('/etc/yum.conf').should == all
    end

  end


end
