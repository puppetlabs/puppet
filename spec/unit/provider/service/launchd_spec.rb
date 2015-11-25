# Spec Tests for the Launchd provider
#

require 'spec_helper'

describe Puppet::Type.type(:service).provider(:launchd) do
  let (:plistlib) { Puppet::Util::Plist }
  let (:joblabel) { "com.foo.food" }
  let (:provider) { subject.class }
  let(:resource) { Puppet::Type.type(:service).new(:name => joblabel, :provider => :launchd) }
  let (:launchd_overrides_6_9) { '/var/db/launchd.db/com.apple.launchd/overrides.plist' }
  let (:launchd_overrides_10_) { '/var/db/com.apple.xpc.launchd/disabled.plist' }
  subject { resource.provider }

  describe "the type interface" do
    %w{ start stop enabled? enable disable status}.each do |method|
      it { is_expected.to respond_to method.to_sym }
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
      expect(provider.prefetch({}).last.status).to eq :stopped
    end
    it "should return running if listed in launchctl list output" do
      provider.expects(:launchctl).with(:list).returns('com.bar.is_running')
      provider.expects(:jobsearch).with(nil).returns({'com.bar.is_running' => "/Library/LaunchDaemons/com.bar.is_running"})
      expect(provider.prefetch({}).last.status).to eq :running
    end
    after :each do
      provider.instance_variable_set(:@job_list, nil)
    end
  end

  [[10, '10.6'], [13, '10.9']].each do |kernel, version|
    describe "when checking whether the service is enabled on OS X #{version}" do
      it "should return true if the job plist says disabled is true and the global overrides says disabled is false" do
        provider.expects(:get_os_version).returns(kernel).at_least_once
        subject.expects(:plist_from_label).returns([joblabel, {"Disabled" => true}])
        plistlib.expects(:read_plist_file).with(launchd_overrides_6_9).returns({joblabel => {"Disabled" => false}})
        FileTest.expects(:file?).with(launchd_overrides_6_9).returns(true)
        expect(subject.enabled?).to eq(:true)
      end
      it "should return false if the job plist says disabled is false and the global overrides says disabled is true" do
        provider.expects(:get_os_version).returns(kernel).at_least_once
        subject.expects(:plist_from_label).returns([joblabel, {"Disabled" => false}])
        plistlib.expects(:read_plist_file).with(launchd_overrides_6_9).returns({joblabel => {"Disabled" => true}})
        FileTest.expects(:file?).with(launchd_overrides_6_9).returns(true)
        expect(subject.enabled?).to eq(:false)
      end
      it "should return true if the job plist and the global overrides have no disabled keys" do
        provider.expects(:get_os_version).returns(kernel).at_least_once
        subject.expects(:plist_from_label).returns([joblabel, {}])
        plistlib.expects(:read_plist_file).with(launchd_overrides_6_9).returns({})
        FileTest.expects(:file?).with(launchd_overrides_6_9).returns(true)
        expect(subject.enabled?).to eq(:true)
      end
    end
  end

  describe "when checking whether the service is enabled on OS X 10.10" do
    it "should return true if the job plist says disabled is true and the global overrides says disabled is false" do
      provider.expects(:get_os_version).returns(14).at_least_once
      subject.expects(:plist_from_label).returns([joblabel, {"Disabled" => true}])
      plistlib.expects(:read_plist_file).with(launchd_overrides_10_).returns({joblabel => false})
      FileTest.expects(:file?).with(launchd_overrides_10_).returns(true)
      expect(subject.enabled?).to eq(:true)
    end
    it "should return false if the job plist says disabled is false and the global overrides says disabled is true" do
      provider.expects(:get_os_version).returns(14).at_least_once
      subject.expects(:plist_from_label).returns([joblabel, {"Disabled" => false}])
      plistlib.expects(:read_plist_file).with(launchd_overrides_10_).returns({joblabel => true})
      FileTest.expects(:file?).with(launchd_overrides_10_).returns(true)
      expect(subject.enabled?).to eq(:false)
    end
    it "should return true if the job plist and the global overrides have no disabled keys" do
      provider.expects(:get_os_version).returns(14).at_least_once
      subject.expects(:plist_from_label).returns([joblabel, {}])
      plistlib.expects(:read_plist_file).with(launchd_overrides_10_).returns({})
      FileTest.expects(:file?).with(launchd_overrides_10_).returns(true)
      expect(subject.enabled?).to eq(:true)
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
      subject.expects(:execute).with([:launchctl, :load, "-w", joblabel])
      subject.start
    end
    it "should execute 'launchctl load' once without writing to the plist if the job is enabled" do
      subject.expects(:plist_from_label).returns([joblabel, {}])
      subject.expects(:enabled?).returns :true
      subject.expects(:execute).with([:launchctl, :load, "-w", joblabel]).once
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

  [[10, "10.6"], [13, "10.9"]].each do |kernel, version|
    describe "when enabling the service on OS X #{version}" do
      it "should write to the global launchd overrides file once" do
        resource[:enable] = true
        provider.expects(:get_os_version).returns(kernel).at_least_once
        plistlib.expects(:read_plist_file).with(launchd_overrides_6_9).returns({})
        plistlib.expects(:write_plist_file).with(has_entry(resource[:name], {'Disabled' => false}), launchd_overrides_6_9).once
        subject.enable
      end
    end

    describe "when disabling the service on OS X #{version}" do
      it "should write to the global launchd overrides file once" do
        resource[:enable] = false
        provider.expects(:get_os_version).returns(kernel).at_least_once
        plistlib.expects(:read_plist_file).with(launchd_overrides_6_9).returns({})
        plistlib.expects(:write_plist_file).with(has_entry(resource[:name], {'Disabled' => true}), launchd_overrides_6_9).once
        subject.disable
      end
    end
  end

  describe "when enabling the service on OS X 10.10" do
    it "should write to the global launchd overrides file once" do
      resource[:enable] = true
      provider.expects(:get_os_version).returns(14).at_least_once
      plistlib.expects(:read_plist_file).with(launchd_overrides_10_).returns({})
      plistlib.expects(:write_plist_file).with(has_entry(resource[:name], false), launchd_overrides_10_).once
      subject.enable
    end
  end

  describe "when disabling the service on OS X 10.10" do
    it "should write to the global launchd overrides file once" do
      resource[:enable] = false
      provider.expects(:get_os_version).returns(14).at_least_once
      plistlib.expects(:read_plist_file).with(launchd_overrides_10_).returns({})
      plistlib.expects(:write_plist_file).with(has_entry(resource[:name], true), launchd_overrides_10_).once
      subject.disable
    end
  end

  describe "make_label_to_path_map" do
    before do
      # clear out this class variable between runs
      if provider.instance_variable_defined? :@label_to_path_map
        provider.send(:remove_instance_variable, :@label_to_path_map)
      end
    end
    describe "when encountering malformed plists" do
      let(:plist_without_label) do
        {
          'LimitLoadToSessionType' => 'Aqua'
        }
      end
      let(:busted_plist_path) { '/Library/LaunchAgents/org.busted.plist' }
      let(:binary_plist_path) { '/Library/LaunchAgents/org.binary.plist' }

      it "[17624] should warn that the plist in question is being skipped" do
        provider.expects(:launchd_paths).returns(['/Library/LaunchAgents'])
        provider.expects(:return_globbed_list_of_file_paths).with('/Library/LaunchAgents').returns([busted_plist_path])
        plistlib.expects(:read_plist_file).with(busted_plist_path).returns(plist_without_label)
        Puppet.expects(:warning).with("The #{busted_plist_path} plist does not contain a 'label' key; Puppet is skipping it")
        provider.make_label_to_path_map
      end
    end
    it "should return the cached value when available" do
      provider.instance_variable_set(:@label_to_path_map, {'xx'=>'yy'})
      expect(provider.make_label_to_path_map).to eq({'xx'=>'yy'})
    end
    describe "when successful" do
      let(:launchd_dir) { '/Library/LaunchAgents' }
      let(:plist) { launchd_dir + '/foo.bar.service.plist' }
      let(:label) { 'foo.bar.service' }
      before do
        provider.instance_variable_set(:@label_to_path_map, nil)
        provider.expects(:launchd_paths).returns([launchd_dir])
        provider.expects(:return_globbed_list_of_file_paths).with(launchd_dir).returns([plist])
        plistlib.expects(:read_plist_file).with(plist).returns({'Label'=>'foo.bar.service'})
      end
      it "should read the plists and return their contents" do
        expect(provider.make_label_to_path_map).to eq({label=>plist})
      end
      it "should re-read the plists and return their contents when refreshed" do
        provider.instance_variable_set(:@label_to_path_map, {'xx'=>'yy'})
        expect(provider.make_label_to_path_map(true)).to eq({label=>plist})
      end
    end
  end

  describe "jobsearch" do
    let(:map) { {"org.mozilla.puppet" => "/path/to/puppet.plist",
                 "org.mozilla.python" => "/path/to/python.plist"} }
    it "returns the entire map with no args" do
      provider.expects(:make_label_to_path_map).returns(map)
      expect(provider.jobsearch).to eq(map)
    end
    it "returns a singleton hash when given a label" do
      provider.expects(:make_label_to_path_map).returns(map)
      expect(provider.jobsearch("org.mozilla.puppet")).to eq({ "org.mozilla.puppet" => "/path/to/puppet.plist" })
    end
    it "refreshes the label_to_path_map when label is not found" do
      provider.expects(:make_label_to_path_map).with().returns({})
      provider.expects(:make_label_to_path_map).with(true).returns(map)
      expect(provider.jobsearch("org.mozilla.puppet")).to eq({ "org.mozilla.puppet" => "/path/to/puppet.plist" })
    end
    it "raises Puppet::Error when the label is still not found" do
      provider.expects(:make_label_to_path_map).with().returns(map)
      provider.expects(:make_label_to_path_map).with(true).returns(map)
      expect { provider.jobsearch("NOSUCH") }.to raise_error(Puppet::Error)
    end
  end
end
