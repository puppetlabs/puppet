require File.join(File.dirname(__FILE__),'../../acceptance_spec_helper.rb')
require 'puppet/acceptance/install_utils'

module InstallUtilsSpec
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
end
end
