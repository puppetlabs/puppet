#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:package).provider(:aptitude) do
  let :type do Puppet::Type.type(:package) end
  let :pkg do
    type.new(:name => 'faff', :provider => :aptitude, :source => '/tmp/faff.deb')
  end

  it { should be_versionable }

  context "when retrieving ensure" do
    before do
      described_class.stubs(:command).with(:dpkgquery).returns 'myquery'
    end

    { :absent   => "deinstall ok config-files faff 1.2.3-1 :DESC: faff summary\n:DESC:\n",
      "1.2.3-1" => "install ok installed faff 1.2.3-1 :DESC: faff summary\n:DESC:\n",
    }.each do |expect, output|
      it "should detect #{expect} packages" do
        Puppet::Util::Execution.expects(:execpipe).
          with(['myquery', '-W', '--showformat', "'${Status} ${Package} ${Version} :DESC: ${Description}\\n:DESC:\\n'", 'faff']).
          yields(StringIO.new(output))

        pkg.property(:ensure).retrieve.should == expect
      end
    end
  end

  it "should try and install when asked" do
    pkg.provider.expects(:aptitude).
      with('-y', '-o', 'DPkg::Options::=--force-confold', :install, 'faff').
      returns(0)

    pkg.provider.install
  end

  it "should try and purge when asked" do
    pkg.provider.expects(:aptitude).with('-y', 'purge', 'faff').returns(0)
    pkg.provider.purge
  end
end
