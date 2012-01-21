# Spec Tests for the Launchd provider
#

require 'spec_helper'

describe Puppet::Type.type(:service).provider(:launchd) do
  let (:joblabel) { "com.foo.food" }
  let (:provider) { subject.class }
  let (:launchd_overrides) { '/var/db/launchd.db/com.apple.launchd/overrides.plist' }

  describe "the type interface" do
    %w{ start stop enabled? enable disable status}.each do |method|
      it { should respond_to method.to_sym }
    end
  end

  describe 'the status of the services' do
    it "should call the external command 'launchctl list' once" do
     provider.expects(:launchctl).with(:list).returns(joblabel)
     provider.expects(:jobsearch).with(nil).returns({joblabel => "/Library/LaunchDaemons/#{joblabel}"})
     provider.prefetch({})
    end
    it "should return stopped if not listed in launchctl list output" do
      provider.expects(:launchctl).with(:list).returns('com.bar.is_running')
      provider.expects(:jobsearch).with(nil).returns({'com.bar.is_not_running' => "/Library/LaunchDaemons/com.bar.is_not_running"})
      provider.prefetch({}).last.status.should eq :stopped
    end
    it "should return running if listed in launchctl list output" do
      provider.expects(:launchctl).with(:list).returns('com.bar.is_running')
      provider.expects(:jobsearch).with(nil).returns({'com.bar.is_running' => "/Library/LaunchDaemons/com.bar.is_running"})
      provider.prefetch({}).last.status.should eq :running
    end
    after :each do
      provider.instance_variable_set(:@job_list, nil)
    end
  end

  describe "when checking whether the service is enabled on OS X 10.5" do
    it "should return true in if the job plist says disabled is false" do
      subject.expects(:has_macosx_plist_overrides?).returns(false)
      subject.expects(:plist_from_label).with(joblabel).returns(["foo", {"Disabled" => false}])
      subject.expects(:resource).returns({:name => joblabel})
      subject.enabled?.should == :true
    end
    it "should return true in if the job plist has no disabled key" do
      subject.expects(:has_macosx_plist_overrides?).returns(false)
      subject.expects(:resource).returns({:name => joblabel})
      subject.expects(:plist_from_label).returns(["foo", {}])
      subject.enabled?.should == :true
    end
    it "should return false in if the job plist says disabled is true" do
      subject.expects(:has_macosx_plist_overrides?).returns(false)
      subject.expects(:resource).returns({:name => joblabel})
      subject.expects(:plist_from_label).returns(["foo", {"Disabled" => true}])
      subject.enabled?.should == :false
    end
  end

  describe "when checking whether the service is enabled on OS X 10.6" do
    it "should return true if the job plist says disabled is true and the global overrides says disabled is false" do
      provider.expects(:get_macosx_version_major).returns("10.6")
      subject.expects(:plist_from_label).returns([joblabel, {"Disabled" => true}])
      provider.expects(:read_plist).returns({joblabel => {"Disabled" => false}})
      FileTest.expects(:file?).with(launchd_overrides).returns(true)
      subject.stubs(:resource).returns({:name => joblabel})
      subject.enabled?.should == :true
    end
    it "should return false if the job plist says disabled is false and the global overrides says disabled is true" do
      provider.expects(:get_macosx_version_major).returns("10.6")
      subject.expects(:plist_from_label).returns([joblabel, {"Disabled" => false}])
      provider.expects(:read_plist).returns({joblabel => {"Disabled" => true}})
      FileTest.expects(:file?).with(launchd_overrides).returns(true)
      subject.stubs(:resource).returns({:name => joblabel})
      subject.enabled?.should == :false
    end
    it "should return true if the job plist and the global overrides have no disabled keys" do
      provider.expects(:get_macosx_version_major).returns("10.6")
      subject.expects(:plist_from_label).returns([joblabel, {}])
      provider.expects(:read_plist).returns({})
      FileTest.expects(:file?).with(launchd_overrides).returns(true)
      subject.stubs(:resource).returns({:name => joblabel})
      subject.enabled?.should == :true
    end
  end

  describe "when starting the service" do
    it "should look for the relevant plist once" do
      subject.expects(:plist_from_label).returns([joblabel, {}]).once
      subject.expects(:enabled?).returns :true
      subject.expects(:execute).with([:launchctl, :load, joblabel])
      subject.stubs(:resource).returns({:name => joblabel})
      subject.start
    end
    it "should execute 'launchctl load' once without writing to the plist if the job is enabled" do  
      subject.expects(:plist_from_label).returns([joblabel, {}])
      subject.expects(:enabled?).returns :true
      subject.expects(:execute).with([:launchctl, :load, joblabel]).once
      subject.stubs(:resource).returns({:name => joblabel})
      subject.start
    end
    it "should execute 'launchctl load' with writing to the plist once if the job is disabled" do
      subject.expects(:plist_from_label).returns([joblabel, {}])
      subject.expects(:enabled?).returns(:false)
      subject.stubs(:resource).returns({:name => joblabel})
      subject.expects(:execute).with([:launchctl, :load, "-w", joblabel]).once
      subject.start
    end
    it "should disable the job once if the job is disabled and should be disabled at boot" do
      subject.expects(:plist_from_label).returns([joblabel, {"Disabled" => true}])
      subject.expects(:enabled?).returns :false
      subject.expects(:execute).with([:launchctl, :load, "-w", joblabel])
      subject.stubs(:resource).returns({:name => joblabel, :enable => :false})
      subject.expects(:disable).once
      subject.start
    end
    it "(#2773) should execute 'launchctl load -w' if the job is enabled but stopped" do
      subject.expects(:plist_from_label).returns([joblabel, {}])
      subject.expects(:enabled?).returns(:true)
      subject.expects(:status).returns(:stopped)
      subject.expects(:resource).returns({:name => joblabel}).twice
      subject.expects(:execute).with([:launchctl, :load, '-w', joblabel])
      subject.start
    end
  end

  describe "when stopping the service" do
    it "should look for the relevant plist once" do
      subject.expects(:plist_from_label).returns([joblabel, {}]).once
      subject.expects(:enabled?).returns :true
      subject.expects(:execute).with([:launchctl, :unload, '-w', joblabel])
      subject.stubs(:resource).returns({:name => joblabel})
      subject.stop
    end
    it "should execute 'launchctl unload' once without writing to the plist if the job is disabled" do
      subject.expects(:plist_from_label).returns([joblabel, {}])
      subject.expects(:enabled?).returns :false
      subject.expects(:execute).with([:launchctl, :unload, joblabel]).once
      subject.stubs(:resource).returns({:name => joblabel})
      subject.stop
    end
    it "should execute 'launchctl unload' with writing to the plist once if the job is enabled" do
      subject.expects(:plist_from_label).returns([joblabel, {}])
      subject.expects(:enabled?).returns :true
      subject.expects(:execute).with([:launchctl, :unload, '-w', joblabel]).once
      subject.stubs(:resource).returns({:name => joblabel})
      subject.stop
    end
    it "should enable the job once if the job is enabled and should be enabled at boot" do
      subject.expects(:plist_from_label).returns([joblabel, {"Disabled" => false}])
      subject.expects(:enabled?).returns :true
      subject.expects(:execute).with([:launchctl, :unload, "-w", joblabel])
      subject.stubs(:resource).returns({:name => joblabel, :enable => :true})
      subject.expects(:enable).once
      subject.stop
    end
  end

  describe "when enabling the service" do
    it "should look for the relevant plist once" do   ### Do we need this test?  Differentiating it?
      subject.expects(:plist_from_label).returns([joblabel, {}]).once
      subject.expects(:enabled?).returns :false
      subject.expects(:execute).with([:launchctl, :unload, joblabel])
      subject.stubs(:resource).returns({:name => joblabel, :enable => :true})
      subject.stop
    end
    it "should check if the job is enabled once" do
      subject.expects(:plist_from_label).returns([joblabel, {}]).once
      subject.expects(:enabled?).once
      subject.expects(:execute).with([:launchctl, :unload, joblabel])
      subject.stubs(:resource).returns({:name => joblabel, :enable => :true})
      subject.stop
    end
  end

  describe "when disabling the service" do
    it "should look for the relevant plist once" do
      subject.expects(:plist_from_label).returns([joblabel, {}]).once
      subject.expects(:enabled?).returns :true
      subject.expects(:execute).with([:launchctl, :unload, '-w', joblabel])
      subject.stubs(:resource).returns({:name => joblabel, :enable => :false})
      subject.stop
    end
  end

  describe "when enabling the service on OS X 10.6" do
    it "should write to the global launchd overrides file once" do
      provider.expects(:get_macosx_version_major).returns("10.6")
      provider.expects(:read_plist).returns({})
      Plist::Emit.expects(:save_plist).once
      subject.stubs(:resource).returns({:name => joblabel, :enable => :true})
      subject.enable
    end
  end

  describe "when disabling the service on OS X 10.6" do
    it "should write to the global launchd overrides file once" do
      provider.stubs(:get_macosx_version_major).returns("10.6")
      provider.stubs(:read_plist).returns({})
      Plist::Emit.expects(:save_plist).once
      subject.stubs(:resource).returns({:name => joblabel, :enable => :false})
      subject.enable
    end
  end

  describe "when using an incompatible version of Facter" do
    before :each do
      provider.instance_variable_set(:@macosx_version_major, nil)
    end
    it "should display a deprecation warning" do
      Facter.expects(:value).with(:macosx_productversion_major).returns(nil)
      Facter.expects(:value).with(:macosx_productversion).returns('10.5.8')
      Facter.expects(:loadfacts)
      Puppet::Util::Warnings.expects(:maybe_log)
      subject.expects(:plist_from_label).returns([joblabel, {"Disabled" => false}])
      subject.expects(:enabled?).returns :false
      File.expects(:open).returns('')
      subject.stubs(:resource).returns({:name => joblabel, :enable => :true})
      subject.enable
    end
  end
end
