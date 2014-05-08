require File.join(File.dirname(__FILE__),'../../acceptance_spec_helper.rb')
require 'puppet/acceptance/install_utils'

describe 'InstallUtils' do

  class ATestCase
    include Puppet::Acceptance::InstallUtils
  end

  class Platform < String

    def with_version_codename
      self
    end
  end

  class TestHost
    attr_accessor :config
    def initialize(config = {})
      self.config = config
    end

    def [](key)
      config[key]
    end
  end

  let(:host) { TestHost.new }
  let(:testcase) { ATestCase.new }

  describe "install_packages_on" do
    it "raises an error if package_hash has unknown platform keys" do
      expect do
        testcase.install_packages_on(host, { :foo => 'bar'})
      end.to raise_error(RuntimeError, /Unknown platform 'foo' in package_hash/)
    end

    shared_examples_for(:install_packages_on) do |platform,command,package|

      let(:package_hash) do
        {
          :redhat => ['rh_package'],
          :debian => [['db_command', 'db_package']],
        }
      end
      let(:additional_switches) { platform == 'debian' ? '--allow-unauthenticated' : nil }

      before do
        logger = mock('logger', :notify => nil)
        host.stubs(:logger).returns(logger)
        host.config['platform'] = Platform.new(platform)
      end

      it "installs packages on a host" do
        host.expects(:check_for_package).never
        host.expects(:install_package).with(package, additional_switches).once
        testcase.install_packages_on(host, package_hash)
      end

      it "checks and installs packages on a host" do
        host.expects(:check_for_package).with(command).once
        host.expects(:install_package).with(package, additional_switches).once
        testcase.install_packages_on(host, package_hash, :check_if_exists => true)
      end
    end

    it_should_behave_like(:install_packages_on, 'fedora', 'rh_package', 'rh_package')
    it_should_behave_like(:install_packages_on, 'debian', 'db_command', 'db_package')
  end

  describe "fetch" do
    before do
      logger = stub('logger', :notify => nil)
      testcase.stubs(:logger).returns(logger)
      FileUtils.expects(:makedirs).with('dir')
    end

    it "does not fetch if destination file already exists" do
      File.expects(:exists?).with('dir/file').returns(true)
      testcase.expects(:open).never
      testcase.fetch('http://foo', 'file', 'dir')
    end

    it "fetches file from url and stores in destination directory as filename" do
      stream = mock('stream')
      file = mock('file')
      testcase.expects(:open).with('http://foo/file').yields(stream)
      File.expects(:open).with('dir/file', 'w').yields(file)
      FileUtils.expects(:copy_stream).with(stream, file)
      testcase.fetch('http://foo', 'file', 'dir')
    end

    it "returns path to destination file" do
      testcase.expects(:open).with('http://foo/file')
      expect(testcase.fetch('http://foo', 'file', 'dir')).to eql('dir/file')
    end
  end

  describe "fetch_remote_dir" do
    before do
      logger = stub('logger', {:notify => nil, :debug => nil})
      testcase.stubs(:logger).returns(logger)
    end

    it "calls wget with the right amount of cut dirs for url that ends in '/'" do
      url = 'http://builds.puppetlabs.lan/puppet/7807591405af849da2ad6534c66bd2d4efff604f/repos/el/6/devel/x86_64/'
      testcase.expects(:`).with("wget -nv -P dir --reject \"index.html*\",\"*.gif\" --cut-dirs=6 -np -nH --no-check-certificate -r #{url} 2>&1").returns("log")

      expect( testcase.fetch_remote_dir(url, 'dir')).to eql('dir/x86_64')
    end

    it "calls wget with the right amount of cut dirs for url that doesn't end in '/'" do
      url = 'http://builds.puppetlabs.lan/puppet/7807591405af849da2ad6534c66bd2d4efff604f/repos/apt/wheezy'
      testcase.expects(:`).with("wget -nv -P dir --reject \"index.html*\",\"*.gif\" --cut-dirs=4 -np -nH --no-check-certificate -r #{url}/ 2>&1").returns("log")

      expect( testcase.fetch_remote_dir(url, 'dir')).to eql('dir/wheezy')
    end

  end

  shared_examples_for :redhat_platforms do |platform,sha,files|
    before do
      host.config['platform'] = Platform.new(platform)
    end

    it "fetches and installs repo configurations for #{platform}" do
      platform_configs_dir = "repo-configs/#{platform}"

      rpm_url = files[:rpm][0]
      rpm_file = files[:rpm][1]
      testcase.expects(:fetch).with(
        "http://yum.puppetlabs.com",
        rpm_file,
        platform_configs_dir
      ).returns("#{platform_configs_dir}/#{rpm_file}")

      repo_url  = files[:repo][0]
      repo_file = files[:repo][1]
      testcase.expects(:fetch).with(
        repo_url,
        repo_file,
        platform_configs_dir
      ).returns("#{platform_configs_dir}/#{repo_file}")

      repo_dir_url = files[:repo_dir][0]
      repo_dir     = files[:repo_dir][1]
      testcase.expects(:link_exists?).returns( true )
      testcase.expects(:fetch_remote_dir).with(
        repo_dir_url,
        platform_configs_dir
      ).returns("#{platform_configs_dir}/#{repo_dir}")
      testcase.expects(:link_exists?).returns( true )
  
      testcase.expects(:on).with(host, regexp_matches(/rm.*repo; rm.*rpm; rm.*#{repo_dir}/))
      testcase.expects(:scp_to).with(host, "#{platform_configs_dir}/#{rpm_file}", '/root')
      testcase.expects(:scp_to).with(host, "#{platform_configs_dir}/#{repo_file}", '/root')
      testcase.expects(:scp_to).with(host, "#{platform_configs_dir}/#{repo_dir}", '/root')
      testcase.expects(:on).with(host, regexp_matches(%r{mv.*repo /etc/yum.repos.d}))
      testcase.expects(:on).with(host, regexp_matches(%r{find /etc/yum.repos.d/ -name .*}))
      testcase.expects(:on).with(host, regexp_matches(%r{rpm.*/root/.*rpm}))

      testcase.install_repos_on(host, sha, 'repo-configs')
    end
  end

  describe "install_repos_on" do
    let(:sha) { "abcdef10" }

    it_should_behave_like(:redhat_platforms,
      'el-6-i386',
      'abcdef10',
      {
        :rpm => [
          "http://yum.puppetlabs.com",
          "puppetlabs-release-el-6.noarch.rpm",
        ],
        :repo => [
          "http://builds.puppetlabs.lan/puppet/abcdef10/repo_configs/rpm/",
          "pl-puppet-abcdef10-el-6-i386.repo",
        ],
        :repo_dir => [
          "http://builds.puppetlabs.lan/puppet/abcdef10/repos/el/6/products/i386/",
          "i386",
        ],
      },
    )

    it_should_behave_like(:redhat_platforms,
      'fedora-20-x86_64',
      'abcdef10',
      {
        :rpm => [
          "http://yum.puppetlabs.com",
          "puppetlabs-release-fedora-20.noarch.rpm",
        ],
        :repo => [
          "http://builds.puppetlabs.lan/puppet/abcdef10/repo_configs/rpm/",
          "pl-puppet-abcdef10-fedora-f20-x86_64.repo",
        ],
        :repo_dir => [
          "http://builds.puppetlabs.lan/puppet/abcdef10/repos/fedora/f20/products/x86_64/",
          "x86_64",
        ],
      },
    )

    it_should_behave_like(:redhat_platforms,
      'centos-5-x86_64',
      'abcdef10',
      {
        :rpm => [
          "http://yum.puppetlabs.com",
          "puppetlabs-release-el-5.noarch.rpm",
        ],
        :repo => [
          "http://builds.puppetlabs.lan/puppet/abcdef10/repo_configs/rpm/",
          "pl-puppet-abcdef10-el-5-x86_64.repo",
        ],
        :repo_dir => [
          "http://builds.puppetlabs.lan/puppet/abcdef10/repos/el/5/products/x86_64/",
          "x86_64",
        ],
      },
    )

    it "installs on a debian host" do
      host.config['platform'] = platform = Platform.new('ubuntu-precise-x86_64')
      platform_configs_dir = "repo-configs/#{platform}"

      deb = "puppetlabs-release-precise.deb"
      testcase.expects(:fetch).with(
        "http://apt.puppetlabs.com/",
        deb,
        platform_configs_dir
      ).returns("#{platform_configs_dir}/#{deb}")

      list = "pl-puppet-#{sha}-precise.list"
      testcase.expects(:fetch).with(
        "http://builds.puppetlabs.lan/puppet/#{sha}/repo_configs/deb/",
        list,
        platform_configs_dir
      ).returns("#{platform_configs_dir}/#{list}")

      testcase.expects(:fetch_remote_dir).with(
        "http://builds.puppetlabs.lan/puppet/#{sha}/repos/apt/precise",
        platform_configs_dir
      ).returns("#{platform_configs_dir}/precise")

      testcase.expects(:on).with(host, regexp_matches(/rm.*list; rm.*deb; rm.*/))
      testcase.expects(:scp_to).with(host, "#{platform_configs_dir}/#{deb}", '/root')
      testcase.expects(:scp_to).with(host, "#{platform_configs_dir}/#{list}", '/root')
      testcase.expects(:scp_to).with(host, "#{platform_configs_dir}/precise", '/root')
      testcase.expects(:on).with(host, regexp_matches(%r{mv.*list /etc/apt/sources.list.d}))
      testcase.expects(:on).with(host, regexp_matches(%r{find /etc/apt/sources.list.d/ -name .*}))
      testcase.expects(:on).with(host, regexp_matches(%r{dpkg -i.*/root/.*deb}))
      testcase.expects(:on).with(host, regexp_matches(%r{apt-get update}))

      testcase.install_repos_on(host, sha, 'repo-configs')
    end
  end
end
