require 'spec_helper'

describe 'Puppet::Type::Service::Provider::Launchd',
         unless: Puppet::Util::Platform.windows? || Puppet::Util::Platform.jruby? do
  let(:provider_class) { Puppet::Type.type(:service).provider(:launchd) }
  let (:plistlib) { Puppet::Util::Plist }
  let (:joblabel) { "com.foo.food" }
  let (:provider) { subject.class }
  let (:resource) { Puppet::Type.type(:service).new(:name => joblabel, :provider => :launchd) }
  let (:launchd_overrides_6_9) { '/var/db/launchd.db/com.apple.launchd/overrides.plist' }
  let (:launchd_overrides_10_) { '/var/db/com.apple.xpc.launchd/disabled.plist' }

  subject { resource.provider }

  after :each do
    provider.instance_variable_set(:@job_list, nil)
  end

  describe "the type interface" do
    %w{ start stop enabled? enable disable status}.each do |method|
      it { is_expected.to respond_to method.to_sym }
    end
  end

  describe 'the status of the services' do
    it "should call the external command 'launchctl list' once" do
      expect(provider).to receive(:launchctl).with(:list).and_return(joblabel)
      expect(provider).to receive(:jobsearch).and_return({joblabel => "/Library/LaunchDaemons/#{joblabel}"})
      provider.prefetch({})
    end

    it "should return stopped if not listed in launchctl list output" do
      expect(provider).to receive(:launchctl).with(:list).and_return('com.bar.is_running')
      expect(provider).to receive(:jobsearch).and_return({'com.bar.is_not_running' => "/Library/LaunchDaemons/com.bar.is_not_running"})
      expect(provider.prefetch({}).last.status).to eq(:stopped)
    end

    it "should return running if listed in launchctl list output" do
      expect(provider).to receive(:launchctl).with(:list).and_return('com.bar.is_running')
      expect(provider).to receive(:jobsearch).and_return({'com.bar.is_running' => "/Library/LaunchDaemons/com.bar.is_running"})
      expect(provider.prefetch({}).last.status).to eq(:running)
    end

    describe "when hasstatus is set to false" do
      before :each do
        resource[:hasstatus] = :false
      end

      it "should use the user-provided status command if present and return running if true" do
        resource[:status] = '/bin/true'
        expect(subject).to receive(:execute)
          .with(["/bin/true"], hash_including(failonfail: false))
          .and_return(Puppet::Util::Execution::ProcessOutput.new('', 0))
        expect(subject.status).to eq(:running)
      end

      it "should use the user-provided status command if present and return stopped if false" do
        resource[:status] = '/bin/false'
        expect(subject).to receive(:execute)
          .with(["/bin/false"], hash_including(failonfail: false))
          .and_return(Puppet::Util::Execution::ProcessOutput.new('', 1))
        expect(subject.status).to eq(:stopped)
      end

      it "should fall back to getpid if no status command is provided" do
        expect(subject).to receive(:getpid).and_return(123)
        expect(subject.status).to eq(:running)
      end
    end
  end

  [[10, '10.6'], [13, '10.9']].each do |kernel, version|
    describe "when checking whether the service is enabled on OS X #{version}" do
      it "should return true if the job plist says disabled is true and the global overrides says disabled is false" do
        expect(provider).to receive(:get_os_version).and_return(kernel).at_least(:once)
        expect(subject).to receive(:plist_from_label).and_return([joblabel, {"Disabled" => true}])
        expect(plistlib).to receive(:read_plist_file).with(launchd_overrides_6_9).and_return({joblabel => {"Disabled" => false}})
        expect(FileTest).to receive(:file?).with(launchd_overrides_6_9).and_return(true)
        expect(subject.enabled?).to eq(:true)
      end

      it "should return false if the job plist says disabled is false and the global overrides says disabled is true" do
        expect(provider).to receive(:get_os_version).and_return(kernel).at_least(:once)
        expect(subject).to receive(:plist_from_label).and_return([joblabel, {"Disabled" => false}])
        expect(plistlib).to receive(:read_plist_file).with(launchd_overrides_6_9).and_return({joblabel => {"Disabled" => true}})
        expect(FileTest).to receive(:file?).with(launchd_overrides_6_9).and_return(true)
        expect(subject.enabled?).to eq(:false)
      end

      it "should return true if the job plist and the global overrides have no disabled keys" do
        expect(provider).to receive(:get_os_version).and_return(kernel).at_least(:once)
        expect(subject).to receive(:plist_from_label).and_return([joblabel, {}])
        expect(plistlib).to receive(:read_plist_file).with(launchd_overrides_6_9).and_return({})
        expect(FileTest).to receive(:file?).with(launchd_overrides_6_9).and_return(true)
        expect(subject.enabled?).to eq(:true)
      end
    end
  end

  describe "when checking whether the service is enabled on OS X 10.10" do
    it "should return true if the job plist says disabled is true and the global overrides says disabled is false" do
      expect(provider).to receive(:get_os_version).and_return(14).at_least(:once)
      expect(subject).to receive(:plist_from_label).and_return([joblabel, {"Disabled" => true}])
      expect(plistlib).to receive(:read_plist_file).with(launchd_overrides_10_).and_return({joblabel => false})
      expect(FileTest).to receive(:file?).with(launchd_overrides_10_).and_return(true)
      expect(subject.enabled?).to eq(:true)
    end

    it "should return false if the job plist says disabled is false and the global overrides says disabled is true" do
      expect(provider).to receive(:get_os_version).and_return(14).at_least(:once)
      expect(subject).to receive(:plist_from_label).and_return([joblabel, {"Disabled" => false}])
      expect(plistlib).to receive(:read_plist_file).with(launchd_overrides_10_).and_return({joblabel => true})
      expect(FileTest).to receive(:file?).with(launchd_overrides_10_).and_return(true)
      expect(subject.enabled?).to eq(:false)
    end

    it "should return true if the job plist and the global overrides have no disabled keys" do
      expect(provider).to receive(:get_os_version).and_return(14).at_least(:once)
      expect(subject).to receive(:plist_from_label).and_return([joblabel, {}])
      expect(plistlib).to receive(:read_plist_file).with(launchd_overrides_10_).and_return({})
      expect(FileTest).to receive(:file?).with(launchd_overrides_10_).and_return(true)
      expect(subject.enabled?).to eq(:true)
    end
  end

  describe "when starting the service" do
    let(:services) { "12345 0 #{joblabel}"  }

    it "should call any explicit 'start' command" do
      resource[:start] = "/bin/false"
      expect(subject).to receive(:execute).with(["/bin/false"], hash_including(failonfail: true))
      subject.start
    end

    it "should look for the relevant plist once" do
      allow(provider).to receive(:launchctl).with(:list).and_return(services)
      expect(subject).to receive(:plist_from_label).and_return([joblabel, {}]).once
      expect(subject).to receive(:enabled?).and_return(:true)
      expect(subject).to receive(:execute).with([:launchctl, :load, "-w", joblabel])
      subject.start
    end

    it "should execute 'launchctl load' once without writing to the plist if the job is enabled" do
      allow(provider).to receive(:launchctl).with(:list).and_return(services)
      expect(subject).to receive(:plist_from_label).and_return([joblabel, {}])
      expect(subject).to receive(:enabled?).and_return(:true)
      expect(subject).to receive(:execute).with([:launchctl, :load, "-w", joblabel]).once
      subject.start
    end

    it "should execute 'launchctl load' with writing to the plist once if the job is disabled" do
      expect(subject).to receive(:plist_from_label).and_return([joblabel, {}])
      expect(subject).to receive(:enabled?).and_return(:false)
      expect(subject).to receive(:execute).with([:launchctl, :load, "-w", joblabel]).once
      subject.start
    end

    it "should disable the job once if the job is disabled and should be disabled at boot" do
      resource[:enable] = false
      expect(subject).to receive(:plist_from_label).and_return([joblabel, {"Disabled" => true}])
      expect(subject).to receive(:enabled?).and_return(:false)
      expect(subject).to receive(:execute).with([:launchctl, :load, "-w", joblabel])
      expect(subject).to receive(:disable).once
      subject.start
    end

    it "(#2773) should execute 'launchctl load -w' if the job is enabled but stopped" do
      expect(subject).to receive(:plist_from_label).and_return([joblabel, {}])
      expect(subject).to receive(:enabled?).and_return(:true)
      expect(subject).to receive(:status).and_return(:stopped)
      expect(subject).to receive(:execute).with([:launchctl, :load, '-w', joblabel])
      subject.start
    end

    it "(#16271) Should stop and start the service when a restart is called" do
      expect(subject).to receive(:stop)
      expect(subject).to receive(:start)
      subject.restart
    end
  end

  describe "when stopping the service" do
    it "should call any explicit 'stop' command" do
      resource[:stop] = "/bin/false"
      expect(subject).to receive(:execute).with(["/bin/false"], hash_including(failonfail: true))
      subject.stop
    end

    it "should look for the relevant plist once" do
      expect(subject).to receive(:plist_from_label).and_return([joblabel, {}]).once
      expect(subject).to receive(:enabled?).and_return(:true)
      expect(subject).to receive(:execute).with([:launchctl, :unload, '-w', joblabel])
      subject.stop
    end

    it "should execute 'launchctl unload' once without writing to the plist if the job is disabled" do
      expect(subject).to receive(:plist_from_label).and_return([joblabel, {}])
      expect(subject).to receive(:enabled?).and_return(:false)
      expect(subject).to receive(:execute).with([:launchctl, :unload, joblabel]).once
      subject.stop
    end

    it "should execute 'launchctl unload' with writing to the plist once if the job is enabled" do
      expect(subject).to receive(:plist_from_label).and_return([joblabel, {}])
      expect(subject).to receive(:enabled?).and_return(:true)
      expect(subject).to receive(:execute).with([:launchctl, :unload, '-w', joblabel]).once
      subject.stop
    end

    it "should enable the job once if the job is enabled and should be enabled at boot" do
      resource[:enable] = true
      expect(subject).to receive(:plist_from_label).and_return([joblabel, {"Disabled" => false}])
      expect(subject).to receive(:enabled?).and_return(:true)
      expect(subject).to receive(:execute).with([:launchctl, :unload, "-w", joblabel])
      expect(subject).to receive(:enable).once
      subject.stop
    end
  end

  describe "when enabling the service" do
    it "should look for the relevant plist once" do   ### Do we need this test?  Differentiating it?
      resource[:enable] = true
      expect(subject).to receive(:plist_from_label).and_return([joblabel, {}]).once
      expect(subject).to receive(:enabled?).and_return(:false)
      expect(subject).to receive(:execute).with([:launchctl, :unload, joblabel])
      subject.stop
    end

    it "should check if the job is enabled once" do
      resource[:enable] = true
      expect(subject).to receive(:plist_from_label).and_return([joblabel, {}]).once
      expect(subject).to receive(:enabled?).once
      expect(subject).to receive(:execute).with([:launchctl, :unload, joblabel])
      subject.stop
    end
  end

  describe "when disabling the service" do
    it "should look for the relevant plist once" do
      resource[:enable] = false
      expect(subject).to receive(:plist_from_label).and_return([joblabel, {}]).once
      expect(subject).to receive(:enabled?).and_return(:true)
      expect(subject).to receive(:execute).with([:launchctl, :unload, '-w', joblabel])
      subject.stop
    end
  end

  describe "when a service is unavailable" do
    let(:map) { {"some.random.job" => "/path/to/job.plist"} }
    
    before :each do
      allow(provider).to receive(:make_label_to_path_map).and_return(map)
    end

    it "should fail when searching for the unavailable service" do
      expect { provider.jobsearch("NOSUCH") }.to raise_error(Puppet::Error)
    end

    it "should return false when enabling the service" do
      expect(subject.enabled?).to eq(:false)
    end

    it "should fail when starting the service" do
      expect { subject.start }.to raise_error(Puppet::Error)
    end

    it "should fail when starting the service" do
      expect { subject.stop }.to raise_error(Puppet::Error)
    end
  end

  [[10, "10.6"], [13, "10.9"]].each do |kernel, version|
    describe "when enabling the service on OS X #{version}" do
      it "should write to the global launchd overrides file once" do
        resource[:enable] = true
        expect(provider).to receive(:get_os_version).and_return(kernel).at_least(:once)
        expect(plistlib).to receive(:read_plist_file).with(launchd_overrides_6_9).and_return({})
        expect(plistlib).to receive(:write_plist_file).with(hash_including(resource[:name] => {'Disabled' => false}), launchd_overrides_6_9).once
        subject.enable
      end
    end

    describe "when disabling the service on OS X #{version}" do
      it "should write to the global launchd overrides file once" do
        resource[:enable] = false
        expect(provider).to receive(:get_os_version).and_return(kernel).at_least(:once)
        expect(plistlib).to receive(:read_plist_file).with(launchd_overrides_6_9).and_return({})
        expect(plistlib).to receive(:write_plist_file).with(hash_including(resource[:name] => {'Disabled' => true}), launchd_overrides_6_9).once
        subject.disable
      end
    end
  end

  describe "when enabling the service on OS X 10.10" do
    it "should write to the global launchd overrides file once" do
      resource[:enable] = true
      expect(provider).to receive(:get_os_version).and_return(14).at_least(:once)
      expect(plistlib).to receive(:read_plist_file).with(launchd_overrides_10_).and_return({})
      expect(plistlib).to receive(:write_plist_file).with(hash_including(resource[:name] => false), launchd_overrides_10_).once
      subject.enable
    end
  end

  describe "when disabling the service on OS X 10.10" do
    it "should write to the global launchd overrides file once" do
      resource[:enable] = false
      expect(provider).to receive(:get_os_version).and_return(14).at_least(:once)
      expect(plistlib).to receive(:read_plist_file).with(launchd_overrides_10_).and_return({})
      expect(plistlib).to receive(:write_plist_file).with(hash_including(resource[:name] => true), launchd_overrides_10_).once
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
      let(:plist_without_label_not_hash) { 'just a string' }
      let(:busted_plist_path) { '/Library/LaunchAgents/org.busted.plist' }
      let(:binary_plist_path) { '/Library/LaunchAgents/org.binary.plist' }

      it "[17624] should warn that the plist in question is being skipped" do
        expect(provider).to receive(:launchd_paths).and_return(['/Library/LaunchAgents'])
        expect(provider).to receive(:return_globbed_list_of_file_paths).with('/Library/LaunchAgents').and_return([busted_plist_path])
        expect(plistlib).to receive(:read_plist_file).with(busted_plist_path).and_return(plist_without_label)
        expect(Puppet).to receive(:debug).with("Reading launchd plist #{busted_plist_path}")
        expect(Puppet).to receive(:debug).with("The #{busted_plist_path} plist does not contain a 'label' key; Puppet is skipping it")
        provider.make_label_to_path_map
      end

      it "it should warn that the malformed plist in question is being skipped" do
        expect(provider).to receive(:launchd_paths).and_return(['/Library/LaunchAgents'])
        expect(provider).to receive(:return_globbed_list_of_file_paths).with('/Library/LaunchAgents').and_return([busted_plist_path])
        expect(plistlib).to receive(:read_plist_file).with(busted_plist_path).and_return(plist_without_label_not_hash)
        expect(Puppet).to receive(:debug).with("Reading launchd plist #{busted_plist_path}")
        expect(Puppet).to receive(:debug).with("The #{busted_plist_path} plist does not contain a 'label' key; Puppet is skipping it")
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
        expect(provider).to receive(:launchd_paths).and_return([launchd_dir])
        expect(provider).to receive(:return_globbed_list_of_file_paths).with(launchd_dir).and_return([plist])
        expect(plistlib).to receive(:read_plist_file).with(plist).and_return({'Label'=>'foo.bar.service'})
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
      expect(provider).to receive(:make_label_to_path_map).and_return(map)
      expect(provider.jobsearch).to eq(map)
    end

    it "returns a singleton hash when given a label" do
      expect(provider).to receive(:make_label_to_path_map).and_return(map)
      expect(provider.jobsearch("org.mozilla.puppet")).to eq({ "org.mozilla.puppet" => "/path/to/puppet.plist" })
    end

    it "refreshes the label_to_path_map when label is not found" do
      expect(provider).to receive(:make_label_to_path_map).and_return(map)
      expect(provider.jobsearch("org.mozilla.puppet")).to eq({ "org.mozilla.puppet" => "/path/to/puppet.plist" })
    end

    it "raises Puppet::Error when the label is still not found" do
      allow(provider).to receive(:make_label_to_path_map).and_return(map)
      expect { provider.jobsearch("NOSUCH") }.to raise_error(Puppet::Error)
    end
  end

  describe "read_overrides" do
    before do
      allow(Kernel).to receive(:sleep)
    end

    it "should read overrides" do
      expect(provider).to receive(:read_plist).once.and_return({})
      expect(provider.read_overrides).to eq({})
    end

    it "should retry if read_plist fails" do
      allow(provider).to receive(:read_plist).and_return({}, nil)
      expect(provider.read_overrides).to eq({})
    end

    it "raises Puppet::Error after 20 attempts" do
      expect(provider).to receive(:read_plist).exactly(20).times().and_return(nil)
      expect { provider.read_overrides }.to raise_error(Puppet::Error)
    end
  end
end
