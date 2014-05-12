#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:package).provider(:aptrpm) do
  let :type do Puppet::Type.type(:package) end
  let :pkg do
    type.new(:name => 'faff', :provider => :aptrpm, :source => '/tmp/faff.rpm')
  end

  it { should be_versionable }

  context "when retrieving ensure" do
    before(:each) do
      Puppet::Util.stubs(:which).with("rpm").returns("/bin/rpm")
      pkg.provider.stubs(:which).with("rpm").returns("/bin/rpm")
      Puppet::Util::Execution.expects(:execute).with(["/bin/rpm", "--version"], {:combine => true, :custom_environment => {}, :failonfail => true}).returns("4.10.1\n").at_most_once
    end

    def rpm_args
      ['-q', 'faff', '--nosignature', '--nodigest', '--qf', "%{NAME} %|EPOCH?{%{EPOCH}}:{0}| %{VERSION} %{RELEASE} %{ARCH}\\n"]
    end

    def rpm(args = rpm_args)
      pkg.provider.expects(:rpm).with(*args)
    end

    it "should report absent packages" do
      rpm.raises(Puppet::ExecutionFailure, "couldn't find rpm")
      pkg.property(:ensure).retrieve.should == :absent
    end

    it "should report present packages correctly" do
      rpm.returns("faff-1.2.3-1 0 1.2.3-1 5 i686\n")
      pkg.property(:ensure).retrieve.should == "1.2.3-1-5"
    end
  end

  it "should try and install when asked" do
    pkg.provider.expects(:aptget). with('-q', '-y', 'install', 'faff'). returns(0)
    pkg.provider.install
  end

  it "should try and purge when asked" do
    pkg.provider.expects(:aptget).with('-y', '-q', 'remove', '--purge', 'faff').returns(0)
    pkg.provider.purge
  end
end
