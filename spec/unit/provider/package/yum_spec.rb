#! /usr/bin/env ruby
require 'spec_helper'

provider = Puppet::Type.type(:package).provider(:yum)

describe provider do
  before do
    # Create a mock resource
     @resource = stub 'resource'
     @resource.stubs(:[]).with(:name).returns 'mypackage'
     @provider = provider.new(@resource)
     @provider.stubs(:resource).returns @resource
     @provider.stubs(:yum).returns 'yum'
     @provider.stubs(:rpm).returns 'rpm'
     @provider.stubs(:get).with(:name).returns 'mypackage'
     @provider.stubs(:get).with(:version).returns '1'
     @provider.stubs(:get).with(:release).returns '1'
     @provider.stubs(:get).with(:arch).returns 'i386'
  end
  # provider should repond to the following methods
   [:install, :latest, :update, :purge].each do |method|
     it "should have a(n) #{method}" do
       @provider.should respond_to(method)
    end
  end

  describe 'package evr parsing' do

    it 'should parse full simple evr' do
      v = @provider.yum_parse_evr('0:1.2.3-4.el5')
      v[:epoch].should == '0'
      v[:version].should == '1.2.3'
      v[:release].should == '4.el5'
    end

    it 'should parse version only' do
      v = @provider.yum_parse_evr('1.2.3')
      v[:epoch].should == '0'
      v[:version].should == '1.2.3'
      v[:release].should == nil
    end

    it 'should parse version-release' do
      v = @provider.yum_parse_evr('1.2.3-4.5.el6')
      v[:epoch].should == '0'
      v[:version].should == '1.2.3'
      v[:release].should == '4.5.el6'
    end

    it 'should parse release with git hash' do
      v = @provider.yum_parse_evr('1.2.3-4.1234aefd')
      v[:epoch].should == '0'
      v[:version].should == '1.2.3'
      v[:release].should == '4.1234aefd'
    end

    it 'should parse single integer versions' do
      v = @provider.yum_parse_evr('12345')
      v[:epoch].should == '0'
      v[:version].should == '12345'
      v[:release].should == nil
    end

    it 'should parse text in the epoch to 0' do
      v = @provider.yum_parse_evr('foo0:1.2.3-4')
      v[:epoch].should == '0'
      v[:version].should == '1.2.3'
      v[:release].should == '4'
    end

    it 'should parse revisions with text' do
      v = @provider.yum_parse_evr('1.2.3-SNAPSHOT20140107')
      v[:epoch].should == '0'
      v[:version].should == '1.2.3'
      v[:release].should == 'SNAPSHOT20140107'
    end

    # test cases for PUP-682
    it 'should parse revisions with text and numbers' do
      v = @provider.yum_parse_evr('2.2-SNAPSHOT20121119105647')
      v[:epoch].should == '0'
      v[:version].should == '2.2'
      v[:release].should == 'SNAPSHOT20121119105647'
    end

  end

  describe 'yum evr comparison' do

    # currently passing tests
    it 'should evaluate identical version-release as equal' do
      v = @provider.yum_compareEVR({:epoch => '0', :version => '1.2.3', :release => '1.el5'},
                                  {:epoch => '0', :version => '1.2.3', :release => '1.el5'})
      v.should == 0
    end

    it 'should evaluate identical version as equal' do
      v = @provider.yum_compareEVR({:epoch => '0', :version => '1.2.3', :release => nil},
                                  {:epoch => '0', :version => '1.2.3', :release => nil})
      v.should == 0
    end

    it 'should evaluate identical version but older release as less' do
      v = @provider.yum_compareEVR({:epoch => '0', :version => '1.2.3', :release => '1.el5'},
                                  {:epoch => '0', :version => '1.2.3', :release => '2.el5'})
      v.should == -1
    end

    it 'should evaluate identical version but newer release as greater' do
      v = @provider.yum_compareEVR({:epoch => '0', :version => '1.2.3', :release => '3.el5'},
                                  {:epoch => '0', :version => '1.2.3', :release => '2.el5'})
      v.should == 1
    end

    it 'should evaluate a newer epoch as greater' do
      v = @provider.yum_compareEVR({:epoch => '1', :version => '1.2.3', :release => '4.5'},
                                  {:epoch => '0', :version => '1.2.3', :release => '4.5'})
      v.should == 1
    end

    # these tests describe PUP-1244 logic yet to be implemented
    it 'should evaluate any version as equal to the same version followed by release' do
      v = @provider.yum_compareEVR({:epoch => '0', :version => '1.2.3', :release => nil},
                                  {:epoch => '0', :version => '1.2.3', :release => '2.el5'})
      v.should == 0
    end

    # test cases for PUP-682
    it 'should evaluate same-length numeric revisions numerically' do
      @provider.yum_compareEVR({:epoch => '0', :version => '2.2', :release => '405'},
                               {:epoch => '0', :version => '2.2', :release => '406'}).should == -1
    end

  end

  describe 'yum version segment comparison' do

    it 'should treat two nil values as equal' do
      v = @provider.compare_values(nil, nil)
      v.should == 0
    end

    it 'should treat a nil value as less than a non-nil value' do
      v = @provider.compare_values(nil, '0')
      v.should == -1
    end

    it 'should treat a non-nil value as greater than a nil value' do
      v = @provider.compare_values('0', nil)
      v.should == 1
    end

    it 'should pass two non-nil values on to rpmvercmp' do
      @provider.stubs(:rpmvercmp) { 0 }
      @provider.expects(:rpmvercmp).with('s1', 's2')
      @provider.compare_values('s1', 's2')
    end

  end

  describe 'when installing' do
    before(:each) do
      Puppet::Util.stubs(:which).with("rpm").returns("/bin/rpm")
      provider.stubs(:which).with("rpm").returns("/bin/rpm")
      Puppet::Util::Execution.expects(:execute).with(["/bin/rpm", "--version"], {:combine => true, :custom_environment => {}, :failonfail => true}).returns("4.10.1\n").at_most_once
    end

    it 'should call yum install for :installed' do
      @resource.stubs(:should).with(:ensure).returns :installed
      @provider.expects(:yum).with('-d', '0', '-e', '0', '-y', :install, 'mypackage')
      @provider.install
    end

    it 'should use :install to update' do
      @provider.expects(:install)
      @provider.update
    end

    it 'should be able to set version' do
      @resource.stubs(:should).with(:ensure).returns '1.2'
      @provider.expects(:yum).with('-d', '0', '-e', '0', '-y', :install, 'mypackage-1.2')
      @provider.stubs(:query).returns :ensure => '1.2'
      @provider.install
    end

    it 'should be able to downgrade' do
      @resource.stubs(:should).with(:ensure).returns '1.0'
      @provider.expects(:yum).with('-d', '0', '-e', '0', '-y', :downgrade, 'mypackage-1.0')
      @provider.stubs(:query).returns(:ensure => '1.2').then.returns(:ensure => '1.0')
      @provider.install
    end
  end

  describe 'when uninstalling' do
    it 'should use erase to purge' do
      @provider.expects(:yum).with('-y', :erase, 'mypackage')
      @provider.purge
    end
  end

  it 'should be versionable' do
    provider.should be_versionable
  end

  describe '#latest' do
    describe 'when latest_info is nil' do
      before :each do
        @provider.stubs(:latest_info).returns(nil)
      end

      it 'raises if ensure is absent and latest_info is nil' do
        @provider.stubs(:properties).returns({:ensure => :absent})

        expect { @provider.latest }.to raise_error(
          Puppet::DevError,
          'Tried to get latest on a missing package'
        )
      end

      it 'returns the ensure value if the package is not already installed' do
        @provider.stubs(:properties).returns({:ensure => '3.4.5'})

        @provider.latest.should == '3.4.5'
      end
    end

    describe 'when latest_info is populated' do
      before :each do
        @provider.stubs(:latest_info).returns({
          :name     => 'mypackage',
          :epoch    => '1',
          :version  => '2.3.4',
          :release  => '5',
          :arch     => 'i686',
          :provider => :yum,
          :ensure   => '2.3.4-5'
        })
      end

      it 'includes the epoch in the version string' do
        @provider.latest.should == '1:2.3.4-5'
      end
    end
  end

  describe 'prefetching' do
    let(:nevra_format) { Puppet::Type::Package::ProviderRpm::NEVRA_FORMAT }

    let(:packages) do
      <<-RPM_OUTPUT
      cracklib-dicts 0 2.8.9 3.3 x86_64
      basesystem 0 8.0 5.1.1.el5.centos noarch
      chkconfig 0 1.3.30.2 2.el5 x86_64
      myresource 0 1.2.3.4 5.el4 noarch
      mysummaryless 0 1.2.3.4 5.el4 noarch
      RPM_OUTPUT
    end

    let(:yumhelper_output) do
      <<-YUMHELPER_OUTPUT
 * base: centos.tcpdiag.net
 * extras: centos.mirrors.hoobly.com
 * updates: mirrors.arsc.edu
_pkg nss-tools 0 3.14.3 4.el6_4 x86_64
_pkg pixman 0 0.26.2 5.el6_4 x86_64
_pkg myresource 0 1.2.3.4 5.el4 noarch
_pkg mysummaryless 0 1.2.3.4 5.el4 noarch
     YUMHELPER_OUTPUT
    end

    let(:execute_options) do
      {:failonfail => true, :combine => true, :custom_environment => {}}
    end

    let(:rpm_version) { "RPM version 4.8.0\n" }

    let(:package_type) { Puppet::Type.type(:package) }
    let(:yum_provider) { provider }

    def pretend_we_are_root_for_yum_provider
      Process.stubs(:euid).returns(0)
    end

    def expect_yum_provider_to_provide_rpm
      Puppet::Type::Package::ProviderYum.stubs(:rpm).with('--version').returns(rpm_version)
      Puppet::Type::Package::ProviderYum.expects(:command).with(:rpm).returns("/bin/rpm")
    end

    def expect_execpipe_to_provide_package_info_for_an_rpm_query
      Puppet::Util::Execution.expects(:execpipe).with("/bin/rpm -qa --nosignature --nodigest --qf '#{nevra_format}'").yields(packages)
    end

    def expect_python_yumhelper_call_to_return_latest_info
      Puppet::Type::Package::ProviderYum.expects(:python).with(regexp_matches(/yumhelper.py$/)).returns(yumhelper_output)
    end

    def a_package_type_instance_with_yum_provider_and_ensure_latest(name)
      type_instance = package_type.new(:name => name)
      type_instance.provider = yum_provider.new
      type_instance[:ensure] = :latest
      return type_instance
    end

    before do
      pretend_we_are_root_for_yum_provider
      expect_yum_provider_to_provide_rpm
      expect_execpipe_to_provide_package_info_for_an_rpm_query
      expect_python_yumhelper_call_to_return_latest_info
    end

    it "injects latest provider info into passed resources when prefetching" do
      myresource = a_package_type_instance_with_yum_provider_and_ensure_latest('myresource')
      mysummaryless = a_package_type_instance_with_yum_provider_and_ensure_latest('mysummaryless')

      yum_provider.prefetch({ "myresource" => myresource, "mysummaryless" => mysummaryless })

      expect(@logs.map(&:message).grep(/^Failed to match rpm line/)).to be_empty
      expect(myresource.provider.latest_info).to eq({
        :name=>"myresource",
        :epoch=>"0",
        :version=>"1.2.3.4",
        :release=>"5.el4",
        :arch=>"noarch",
        :provider=>:yum,
        :ensure=>"1.2.3.4-5.el4"
      })
    end
  end
end
