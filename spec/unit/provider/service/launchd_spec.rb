# Spec Tests for the Launchd provider
#

require 'spec_helper'

describe Puppet::Type.type(:service).provider(:launchd) do
  let (:joblabel) { "com.foo.food" }
  let (:provider) { subject.class }
  let (:launchd_overrides) { '/var/db/launchd.db/com.apple.launchd/overrides.plist' }
  let(:resource) { Puppet::Type.type(:service).new(:name => joblabel, :provider => :launchd) }
  subject { resource.provider }

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
      subject.enabled?.should == :true
    end
    it "should return true in if the job plist has no disabled key" do
      subject.expects(:has_macosx_plist_overrides?).returns(false)
      subject.expects(:plist_from_label).returns(["foo", {}])
      subject.enabled?.should == :true
    end
    it "should return false in if the job plist says disabled is true" do
      subject.expects(:has_macosx_plist_overrides?).returns(false)
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
      subject.enabled?.should == :true
    end
    it "should return false if the job plist says disabled is false and the global overrides says disabled is true" do
      provider.expects(:get_macosx_version_major).returns("10.6")
      subject.expects(:plist_from_label).returns([joblabel, {"Disabled" => false}])
      provider.expects(:read_plist).returns({joblabel => {"Disabled" => true}})
      FileTest.expects(:file?).with(launchd_overrides).returns(true)
      subject.enabled?.should == :false
    end
    it "should return true if the job plist and the global overrides have no disabled keys" do
      provider.expects(:get_macosx_version_major).returns("10.6")
      subject.expects(:plist_from_label).returns([joblabel, {}])
      provider.expects(:read_plist).returns({})
      FileTest.expects(:file?).with(launchd_overrides).returns(true)
      subject.enabled?.should == :true
    end
  end

  describe "when starting the service" do
    it "should call any explicit 'start' command" do
      resource[:start] = "/bin/false"
      subject.expects(:texecute).with(:start, ["/bin/false"], true)
      subject.start
    end

    it "should look for the relevant plist once" do
      subject.expects(:plist_from_label).returns([joblabel, {}]).once
      subject.expects(:enabled?).returns :true
      subject.expects(:execute).with([:launchctl, :load, joblabel])
      subject.start
    end
    it "should execute 'launchctl load' once without writing to the plist if the job is enabled" do
      subject.expects(:plist_from_label).returns([joblabel, {}])
      subject.expects(:enabled?).returns :true
      subject.expects(:execute).with([:launchctl, :load, joblabel]).once
      subject.start
    end
    it "should execute 'launchctl load' with writing to the plist once if the job is disabled" do
      subject.expects(:plist_from_label).returns([joblabel, {}])
      subject.expects(:enabled?).returns(:false)
      subject.expects(:execute).with([:launchctl, :load, "-w", joblabel]).once
      subject.start
    end
    it "should disable the job once if the job is disabled and should be disabled at boot" do
      resource[:enable] = false
      subject.expects(:plist_from_label).returns([joblabel, {"Disabled" => true}])
      subject.expects(:enabled?).returns :false
      subject.expects(:execute).with([:launchctl, :load, "-w", joblabel])
      subject.expects(:disable).once
      subject.start
    end
    it "(#2773) should execute 'launchctl load -w' if the job is enabled but stopped" do
      subject.expects(:plist_from_label).returns([joblabel, {}])
      subject.expects(:enabled?).returns(:true)
      subject.expects(:status).returns(:stopped)
      subject.expects(:execute).with([:launchctl, :load, '-w', joblabel])
      subject.start
    end

    it "(#16271) Should stop and start the service when a restart is called" do
      subject.expects(:stop)
      subject.expects(:start)
      subject.restart
    end
  end

  describe "when stopping the service" do
    it "should call any explicit 'stop' command" do
      resource[:stop] = "/bin/false"
      subject.expects(:texecute).with(:stop, ["/bin/false"], true)
      subject.stop
    end

    it "should look for the relevant plist once" do
      subject.expects(:plist_from_label).returns([joblabel, {}]).once
      subject.expects(:enabled?).returns :true
      subject.expects(:execute).with([:launchctl, :unload, '-w', joblabel])
      subject.stop
    end
    it "should execute 'launchctl unload' once without writing to the plist if the job is disabled" do
      subject.expects(:plist_from_label).returns([joblabel, {}])
      subject.expects(:enabled?).returns :false
      subject.expects(:execute).with([:launchctl, :unload, joblabel]).once
      subject.stop
    end
    it "should execute 'launchctl unload' with writing to the plist once if the job is enabled" do
      subject.expects(:plist_from_label).returns([joblabel, {}])
      subject.expects(:enabled?).returns :true
      subject.expects(:execute).with([:launchctl, :unload, '-w', joblabel]).once
      subject.stop
    end
    it "should enable the job once if the job is enabled and should be enabled at boot" do
      resource[:enable] = true
      subject.expects(:plist_from_label).returns([joblabel, {"Disabled" => false}])
      subject.expects(:enabled?).returns :true
      subject.expects(:execute).with([:launchctl, :unload, "-w", joblabel])
      subject.expects(:enable).once
      subject.stop
    end
  end

  describe "when enabling the service" do
    it "should look for the relevant plist once" do   ### Do we need this test?  Differentiating it?
      resource[:enable] = true
      subject.expects(:plist_from_label).returns([joblabel, {}]).once
      subject.expects(:enabled?).returns :false
      subject.expects(:execute).with([:launchctl, :unload, joblabel])
      subject.stop
    end
    it "should check if the job is enabled once" do
      resource[:enable] = true
      subject.expects(:plist_from_label).returns([joblabel, {}]).once
      subject.expects(:enabled?).once
      subject.expects(:execute).with([:launchctl, :unload, joblabel])
      subject.stop
    end
  end

  describe "when disabling the service" do
    it "should look for the relevant plist once" do
      resource[:enable] = false
      subject.expects(:plist_from_label).returns([joblabel, {}]).once
      subject.expects(:enabled?).returns :true
      subject.expects(:execute).with([:launchctl, :unload, '-w', joblabel])
      subject.stop
    end
  end

  describe "when enabling the service on OS X 10.6" do
    it "should write to the global launchd overrides file once" do
      resource[:enable] = true
      provider.expects(:get_macosx_version_major).returns("10.6")
      provider.expects(:read_plist).returns({})
      Plist::Emit.expects(:save_plist).once
      subject.enable
    end
  end

  describe "when disabling the service on OS X 10.6" do
    it "should write to the global launchd overrides file once" do
      resource[:enable] = false
      provider.stubs(:get_macosx_version_major).returns("10.6")
      provider.stubs(:read_plist).returns({})
      Plist::Emit.expects(:save_plist).once
      subject.enable
    end
  end

  describe "when encountering malformed plists" do
    let(:plist_without_label) do
      {
        'LimitLoadToSessionType' => 'Aqua'
      }
    end
    let(:busted_plist_path) { '/Library/LaunchAgents/org.busted.plist' }

    it "[17624] should warn that the plist in question is being skipped" do
      provider.expects(:launchd_paths).returns(['/Library/LaunchAgents'])
      provider.expects(:return_globbed_list_of_file_paths).with('/Library/LaunchAgents').returns([busted_plist_path])
      provider.expects(:read_plist).with(busted_plist_path).returns(plist_without_label)
      Puppet.expects(:warning).with("The #{busted_plist_path} plist does not contain a 'label' key; Puppet is skipping it")
      provider.jobsearch
    end

    it "[15929] should skip plists that plutil cannot read" do
      provider.expects(:plutil).with('-convert', 'xml1', '-o', '/dev/stdout',
        busted_plist_path).raises(Puppet::ExecutionFailure, 'boom')
      Puppet.expects(:warning).with("Cannot read file #{busted_plist_path}; " +
                                    "Puppet is skipping it. \n" +
                                    "Details: boom")
      provider.read_plist(busted_plist_path)
    end
  end
end
