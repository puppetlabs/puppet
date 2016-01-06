#! /usr/bin/env ruby
require 'spec_helper'


describe Puppet::Type.type(:service).provider(:upstart) do
  let(:manual) { "\nmanual" }
  let(:start_on_default_runlevels) {  "\nstart on runlevel [2,3,4,5]" }
  let(:provider_class) { Puppet::Type.type(:service).provider(:upstart) }

  def given_contents_of(file, content)
    File.open(file, 'w') do |file|
      file.write(content)
    end
  end

  def then_contents_of(file)
    File.open(file).read
  end

  def lists_processes_as(output)
    Puppet::Util::Execution.stubs(:execpipe).with("/sbin/initctl list").yields(output)
    provider_class.stubs(:which).with("/sbin/initctl").returns("/sbin/initctl")
  end

  it "should be the default provider on Ubuntu" do
    Facter.expects(:value).with(:operatingsystem).returns("Ubuntu")
    Facter.expects(:value).with(:operatingsystemmajrelease).returns("12.04")
    expect(described_class.default?).to be_truthy
  end

  describe "excluding services" do
    it "ignores tty and serial on Redhat systems" do
      Facter.stubs(:value).with(:osfamily).returns('RedHat')
      expect(described_class.excludes).to include 'serial'
      expect(described_class.excludes).to include 'tty'
    end
  end

  describe "#instances" do
    it "should be able to find all instances" do
      lists_processes_as("rc stop/waiting\nssh start/running, process 712")

      expect(provider_class.instances.map {|provider| provider.name}).to match_array(["rc","ssh"])
    end

    it "should attach the interface name for network interfaces" do
      lists_processes_as("network-interface (eth0)")

      expect(provider_class.instances.first.name).to eq("network-interface INTERFACE=eth0")
    end

    it "should attach the job name for network interface security" do
      processes = "network-interface-security (network-interface/eth0)"
      provider_class.stubs(:execpipe).yields(processes)
      expect(provider_class.instances.first.name).to eq("network-interface-security JOB=network-interface/eth0")
    end

    it "should not find excluded services" do
      processes = "wait-for-state stop/waiting"
      processes += "\nportmap-wait start/running"
      processes += "\nidmapd-mounting stop/waiting"
      processes += "\nstartpar-bridge start/running"
      processes += "\ncryptdisks-udev stop/waiting"
      processes += "\nstatd-mounting stop/waiting"
      processes += "\ngssd-mounting stop/waiting"
      provider_class.stubs(:execpipe).yields(processes)
      expect(provider_class.instances).to be_empty
    end
  end

  describe "#search" do
    it "searches through paths to find a matching conf file" do
      File.stubs(:directory?).returns(true)
      Puppet::FileSystem.stubs(:exist?).returns(false)
      Puppet::FileSystem.expects(:exist?).with("/etc/init/foo-bar.conf").returns(true)
      resource = Puppet::Type.type(:service).new(:name => "foo-bar", :provider => :upstart)
      provider = provider_class.new(resource)

      expect(provider.initscript).to eq("/etc/init/foo-bar.conf")
    end

    it "searches for just the name of a compound named service" do
      File.stubs(:directory?).returns(true)
      Puppet::FileSystem.stubs(:exist?).returns(false)
      Puppet::FileSystem.expects(:exist?).with("/etc/init/network-interface.conf").returns(true)
      resource = Puppet::Type.type(:service).new(:name => "network-interface INTERFACE=lo", :provider => :upstart)
      provider = provider_class.new(resource)

      expect(provider.initscript).to eq("/etc/init/network-interface.conf")
    end
  end

  describe "#status" do
    it "should use the default status command if none is specified" do
      resource = Puppet::Type.type(:service).new(:name => "foo", :provider => :upstart)
      provider = provider_class.new(resource)
      provider.stubs(:is_upstart?).returns(true)

      provider.expects(:status_exec).with(["foo"]).returns("foo start/running, process 1000")
      Process::Status.any_instance.stubs(:exitstatus).returns(0)
      expect(provider.status).to eq(:running)
    end

    describe "when a special status command is specifed" do
      it "should use the provided status command" do
        resource = Puppet::Type.type(:service).new(:name => 'foo', :provider => :upstart, :status => '/bin/foo')
        provider = provider_class.new(resource)
        provider.stubs(:is_upstart?).returns(true)

        provider.expects(:status_exec).with(['foo']).never
        provider.expects(:execute).with(['/bin/foo'], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
        Process::Status.any_instance.stubs(:exitstatus).returns(0)
        provider.status
      end

      it "should return :stopped when the provided status command return non-zero" do
        resource = Puppet::Type.type(:service).new(:name => 'foo', :provider => :upstart, :status => '/bin/foo')
        provider = provider_class.new(resource)
        provider.stubs(:is_upstart?).returns(true)

        provider.expects(:status_exec).with(['foo']).never
        provider.expects(:execute).with(['/bin/foo'], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
        $CHILD_STATUS.stubs(:exitstatus).returns 1
        expect(provider.status).to eq(:stopped)
      end

      it "should return :running when the provided status command return zero" do
        resource = Puppet::Type.type(:service).new(:name => 'foo', :provider => :upstart, :status => '/bin/foo')
        provider = provider_class.new(resource)
        provider.stubs(:is_upstart?).returns(true)

        provider.expects(:status_exec).with(['foo']).never
        provider.expects(:execute).with(['/bin/foo'], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
        $CHILD_STATUS.stubs(:exitstatus).returns 0
        expect(provider.status).to eq(:running)
      end
    end

    describe "when :hasstatus is set to false" do
      it "should return :stopped if the pid can not be found" do
        resource = Puppet::Type.type(:service).new(:name => 'foo', :hasstatus => false, :provider => :upstart)
        provider = provider_class.new(resource)
        provider.stubs(:is_upstart?).returns(true)

        provider.expects(:status_exec).with(['foo']).never
        provider.expects(:getpid).returns nil
        expect(provider.status).to eq(:stopped)
      end

      it "should return :running if the pid can be found" do
        resource = Puppet::Type.type(:service).new(:name => 'foo', :hasstatus => false, :provider => :upstart)
        provider = provider_class.new(resource)
        provider.stubs(:is_upstart?).returns(true)

        provider.expects(:status_exec).with(['foo']).never
        provider.expects(:getpid).returns 2706
        expect(provider.status).to eq(:running)
      end
    end

    describe "when a special status command is specifed" do
      it "should use the provided status command" do
        resource = Puppet::Type.type(:service).new(:name => 'foo', :provider => :upstart, :status => '/bin/foo')
        provider = provider_class.new(resource)
        provider.stubs(:is_upstart?).returns(true)

        provider.expects(:status_exec).with(['foo']).never
        provider.expects(:execute).with(['/bin/foo'], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
        Process::Status.any_instance.stubs(:exitstatus).returns(0)
        provider.status
      end

      it "should return :stopped when the provided status command return non-zero" do
        resource = Puppet::Type.type(:service).new(:name => 'foo', :provider => :upstart, :status => '/bin/foo')
        provider = provider_class.new(resource)
        provider.stubs(:is_upstart?).returns(true)

        provider.expects(:status_exec).with(['foo']).never
        provider.expects(:execute).with(['/bin/foo'], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
        $CHILD_STATUS.stubs(:exitstatus).returns 1
        expect(provider.status).to eq(:stopped)
      end

      it "should return :running when the provided status command return zero" do
        resource = Puppet::Type.type(:service).new(:name => 'foo', :provider => :upstart, :status => '/bin/foo')
        provider = provider_class.new(resource)
        provider.stubs(:is_upstart?).returns(true)

        provider.expects(:status_exec).with(['foo']).never
        provider.expects(:execute).with(['/bin/foo'], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
        $CHILD_STATUS.stubs(:exitstatus).returns 0
        expect(provider.status).to eq(:running)
      end
    end

    describe "when :hasstatus is set to false" do
      it "should return :stopped if the pid can not be found" do
        resource = Puppet::Type.type(:service).new(:name => 'foo', :hasstatus => false, :provider => :upstart)
        provider = provider_class.new(resource)
        provider.stubs(:is_upstart?).returns(true)

        provider.expects(:status_exec).with(['foo']).never
        provider.expects(:getpid).returns nil
        expect(provider.status).to eq(:stopped)
      end

      it "should return :running if the pid can be found" do
        resource = Puppet::Type.type(:service).new(:name => 'foo', :hasstatus => false, :provider => :upstart)
        provider = provider_class.new(resource)
        provider.stubs(:is_upstart?).returns(true)

        provider.expects(:status_exec).with(['foo']).never
        provider.expects(:getpid).returns 2706
        expect(provider.status).to eq(:running)
      end
    end

    it "should properly handle services with 'start' in their name" do
      resource = Puppet::Type.type(:service).new(:name => "foostartbar", :provider => :upstart)
      provider = provider_class.new(resource)
      provider.stubs(:is_upstart?).returns(true)

      provider.expects(:status_exec).with(["foostartbar"]).returns("foostartbar stop/waiting")
      Process::Status.any_instance.stubs(:exitstatus).returns(0)
      expect(provider.status).to eq(:stopped)
    end
  end

  describe "inheritance" do
    let :resource do
      resource = Puppet::Type.type(:service).new(:name => "foo", :provider => :upstart)
    end

    let :provider do
      provider = provider_class.new(resource)
    end

    describe "when upstart job" do
      before(:each) do
        provider.stubs(:is_upstart?).returns(true)
      end
      ["start", "stop"].each do |command|
        it "should return the #{command}cmd of its parent provider" do
          expect(provider.send("#{command}cmd".to_sym)).to eq([provider.command(command.to_sym), resource.name])
        end
      end
      it "should return nil for the statuscmd" do
        expect(provider.statuscmd).to be_nil
      end
    end
  end

  describe "should be enableable" do
    let :resource do
      Puppet::Type.type(:service).new(:name => "foo", :provider => :upstart)
    end

    let :provider do
      provider_class.new(resource)
    end

    let :init_script do
      PuppetSpec::Files.tmpfile("foo.conf")
    end

    let :over_script do
      PuppetSpec::Files.tmpfile("foo.override")
    end

    let :disabled_content do
      "\t #  \t start on\nother file stuff"
    end

    let :multiline_disabled do
      "# \t  start on other file stuff (\n" +
       "#   more stuff ( # )))))inline comment\n" +
       "#   finishing up )\n" +
       "#   and done )\n" +
       "this line shouldn't be touched\n"
    end

    let :multiline_disabled_bad do
      "# \t  start on other file stuff (\n" +
       "#   more stuff ( # )))))inline comment\n" +
       "#   finishing up )\n" +
       "#   and done )\n" +
       "#   this is a comment i want to be a comment\n" +
       "this line shouldn't be touched\n"
    end

    let :multiline_enabled_bad do
      " \t  start on other file stuff (\n" +
       "   more stuff ( # )))))inline comment\n" +
       "   finishing up )\n" +
       "   and done )\n" +
       "#   this is a comment i want to be a comment\n" +
       "this line shouldn't be touched\n"
    end

    let :multiline_enabled do
      " \t  start on other file stuff (\n" +
       "   more stuff ( # )))))inline comment\n" +
       "   finishing up )\n" +
       "   and done )\n" +
       "this line shouldn't be touched\n"
    end

    let :multiline_enabled_standalone do
      " \t  start on other file stuff (\n" +
       "   more stuff ( # )))))inline comment\n" +
       "   finishing up )\n" +
       "   and done )\n"
    end

    let :enabled_content do
      "\t   \t start on\nother file stuff"
    end

    let :content do
      "just some text"
    end

    describe "Upstart version < 0.6.7" do
      before(:each) do
        provider.stubs(:is_upstart?).returns(true)
        provider.stubs(:upstart_version).returns("0.6.5")
        provider.stubs(:search).returns(init_script)
      end

      [:enabled?,:enable,:disable].each do |enableable|
        it "should respond to #{enableable}" do
          expect(provider).to respond_to(enableable)
        end
      end

      describe "when enabling" do
        it "should open and uncomment the '#start on' line" do
          given_contents_of(init_script, disabled_content)

          provider.enable

          expect(then_contents_of(init_script)).to eq(enabled_content)
        end

        it "should add a 'start on' line if none exists" do
          given_contents_of(init_script, "this is a file")

          provider.enable

          expect(then_contents_of(init_script)).to eq("this is a file" + start_on_default_runlevels)
        end

        it "should handle multiline 'start on' stanzas" do
          given_contents_of(init_script, multiline_disabled)

          provider.enable

          expect(then_contents_of(init_script)).to eq(multiline_enabled)
        end

        it "should leave not 'start on' comments alone" do
          given_contents_of(init_script, multiline_disabled_bad)

          provider.enable

          expect(then_contents_of(init_script)).to eq(multiline_enabled_bad)
        end
      end

      describe "when disabling" do
        it "should open and comment the 'start on' line" do
          given_contents_of(init_script, enabled_content)

          provider.disable

          expect(then_contents_of(init_script)).to eq("#" + enabled_content)
        end

        it "should handle multiline 'start on' stanzas" do
          given_contents_of(init_script, multiline_enabled)

          provider.disable

          expect(then_contents_of(init_script)).to eq(multiline_disabled)
        end
      end

      describe "when checking whether it is enabled" do
        it "should consider 'start on ...' to be enabled" do
          given_contents_of(init_script, enabled_content)

          expect(provider.enabled?).to eq(:true)
        end

        it "should consider '#start on ...' to be disabled" do
          given_contents_of(init_script, disabled_content)

          expect(provider.enabled?).to eq(:false)
        end

        it "should consider no start on line to be disabled" do
          given_contents_of(init_script, content)

          expect(provider.enabled?).to eq(:false)
        end
      end
      end

    describe "Upstart version < 0.9.0" do
      before(:each) do
        provider.stubs(:is_upstart?).returns(true)
        provider.stubs(:upstart_version).returns("0.7.0")
        provider.stubs(:search).returns(init_script)
      end

      [:enabled?,:enable,:disable].each do |enableable|
        it "should respond to #{enableable}" do
          expect(provider).to respond_to(enableable)
        end
      end

      describe "when enabling" do
        it "should open and uncomment the '#start on' line" do
          given_contents_of(init_script, disabled_content)

          provider.enable

          expect(then_contents_of(init_script)).to eq(enabled_content)
        end

        it "should add a 'start on' line if none exists" do
          given_contents_of(init_script, "this is a file")

          provider.enable

          expect(then_contents_of(init_script)).to eq("this is a file" + start_on_default_runlevels)
        end

        it "should handle multiline 'start on' stanzas" do
          given_contents_of(init_script, multiline_disabled)

          provider.enable

          expect(then_contents_of(init_script)).to eq(multiline_enabled)
        end

        it "should remove manual stanzas" do
          given_contents_of(init_script, multiline_enabled + manual)

          provider.enable

          expect(then_contents_of(init_script)).to eq(multiline_enabled)
        end

        it "should leave not 'start on' comments alone" do
          given_contents_of(init_script, multiline_disabled_bad)

          provider.enable

          expect(then_contents_of(init_script)).to eq(multiline_enabled_bad)
        end
      end

      describe "when disabling" do
        it "should add a manual stanza" do
          given_contents_of(init_script, enabled_content)

          provider.disable

          expect(then_contents_of(init_script)).to eq(enabled_content + manual)
        end

        it "should remove manual stanzas before adding new ones" do
          given_contents_of(init_script, multiline_enabled + manual + "\n" + multiline_enabled)

          provider.disable

          expect(then_contents_of(init_script)).to eq(multiline_enabled + "\n" + multiline_enabled + manual)
        end

        it "should handle multiline 'start on' stanzas" do
          given_contents_of(init_script, multiline_enabled)

          provider.disable

          expect(then_contents_of(init_script)).to eq(multiline_enabled + manual)
        end
      end

      describe "when checking whether it is enabled" do
        describe "with no manual stanza" do
          it "should consider 'start on ...' to be enabled" do
            given_contents_of(init_script, enabled_content)

            expect(provider.enabled?).to eq(:true)
          end

          it "should consider '#start on ...' to be disabled" do
            given_contents_of(init_script, disabled_content)

            expect(provider.enabled?).to eq(:false)
          end

          it "should consider no start on line to be disabled" do
            given_contents_of(init_script, content)

            expect(provider.enabled?).to eq(:false)
          end
        end

        describe "with manual stanza" do
          it "should consider 'start on ...' to be disabled if there is a trailing manual stanza" do
            given_contents_of(init_script, enabled_content + manual + "\nother stuff")

            expect(provider.enabled?).to eq(:false)
          end

          it "should consider two start on lines with a manual in the middle to be enabled" do
            given_contents_of(init_script, enabled_content + manual + "\n" + enabled_content)

            expect(provider.enabled?).to eq(:true)
          end
        end
      end
    end

    describe "Upstart version > 0.9.0" do
      before(:each) do
        provider.stubs(:is_upstart?).returns(true)
        provider.stubs(:upstart_version).returns("0.9.5")
        provider.stubs(:search).returns(init_script)
        provider.stubs(:overscript).returns(over_script)
      end

      [:enabled?,:enable,:disable].each do |enableable|
        it "should respond to #{enableable}" do
          expect(provider).to respond_to(enableable)
        end
      end

      describe "when enabling" do
        it "should add a 'start on' line if none exists" do
          given_contents_of(init_script, "this is a file")

          provider.enable

          expect(then_contents_of(init_script)).to eq("this is a file")
          expect(then_contents_of(over_script)).to eq(start_on_default_runlevels)
        end

        it "should handle multiline 'start on' stanzas" do
          given_contents_of(init_script, multiline_disabled)

          provider.enable

          expect(then_contents_of(init_script)).to eq(multiline_disabled)
          expect(then_contents_of(over_script)).to eq(start_on_default_runlevels)
        end

        it "should remove any manual stanzas from the override file" do
          given_contents_of(over_script, manual)
          given_contents_of(init_script, enabled_content)

          provider.enable

          expect(then_contents_of(init_script)).to eq(enabled_content)
          expect(then_contents_of(over_script)).to eq("")
        end

        it "should copy existing start on from conf file if conf file is disabled" do
          given_contents_of(init_script, multiline_enabled_standalone + manual)

          provider.enable

          expect(then_contents_of(init_script)).to eq(multiline_enabled_standalone + manual)
          expect(then_contents_of(over_script)).to eq(multiline_enabled_standalone)
        end

        it "should leave not 'start on' comments alone" do
          given_contents_of(init_script, multiline_disabled_bad)
          given_contents_of(over_script, "")

          provider.enable

          expect(then_contents_of(init_script)).to eq(multiline_disabled_bad)
          expect(then_contents_of(over_script)).to eq(start_on_default_runlevels)
        end
      end

      describe "when disabling" do
        it "should add a manual stanza to the override file" do
          given_contents_of(init_script, enabled_content)

          provider.disable

          expect(then_contents_of(init_script)).to eq(enabled_content)
          expect(then_contents_of(over_script)).to eq(manual)
        end

        it "should handle multiline 'start on' stanzas" do
          given_contents_of(init_script, multiline_enabled)

          provider.disable

          expect(then_contents_of(init_script)).to eq(multiline_enabled)
          expect(then_contents_of(over_script)).to eq(manual)
        end
      end

      describe "when checking whether it is enabled" do
        describe "with no override file" do
          it "should consider 'start on ...' to be enabled" do
            given_contents_of(init_script, enabled_content)

            expect(provider.enabled?).to eq(:true)
          end

          it "should consider '#start on ...' to be disabled" do
            given_contents_of(init_script, disabled_content)

            expect(provider.enabled?).to eq(:false)
          end

          it "should consider no start on line to be disabled" do
            given_contents_of(init_script, content)

            expect(provider.enabled?).to eq(:false)
          end
        end
        describe "with override file" do
          it "should consider 'start on ...' to be disabled if there is manual in override file" do
            given_contents_of(init_script, enabled_content)
            given_contents_of(over_script, manual + "\nother stuff")

            expect(provider.enabled?).to eq(:false)
          end

          it "should consider '#start on ...' to be enabled if there is a start on in the override file" do
            given_contents_of(init_script, disabled_content)
            given_contents_of(over_script, "start on stuff")

            expect(provider.enabled?).to eq(:true)
          end
        end
      end
    end
  end
end
