#!/usr/bin/env rspec
require 'spec_helper'

provider_class = Puppet::Type.type(:service).provider(:upstart)

describe provider_class do
  describe "#instances" do
    it "should be able to find all instances" do
      processes = ["rc stop/waiting", "ssh start/running, process 712"].join("\n")
      provider_class.stubs(:execpipe).yields(processes)
      provider_class.instances.map {|provider| provider.name}.should =~ ["rc","ssh"]
    end

    it "should attach the interface name for network interfaces" do
      processes = ["network-interface (eth0)"].join("\n")
      provider_class.stubs(:execpipe).yields(processes)
      provider_class.instances.first.name.should == "network-interface INTERFACE=eth0"
    end
  end

  describe "#status" do
    it "should allow the user to override the status command" do
      resource = Puppet::Type.type(:service).new(:name => "foo", :provider => :upstart, :status => "/bin/foo")
      provider = provider_class.new(resource)

      # Because we stub execution, we also need to stub the result of it, or a
      # previously failing command execution will cause this test to do the
      # wrong thing.
      provider.expects(:ucommand)
      $?.stubs(:exitstatus).returns(0)
      provider.status.should == :running
    end

    it "should use the default status command if none is specified" do
      resource = Puppet::Type.type(:service).new(:name => "foo", :provider => :upstart)
      provider = provider_class.new(resource)
      provider.stubs(:is_upstart?).returns(true)

      provider.expects(:status_exec).with(["foo"]).returns("foo start/running, process 1000")
      Process::Status.any_instance.stubs(:exitstatus).returns(0)
      provider.status.should == :running
    end

    it "should properly handle services with 'start' in their name" do
      resource = Puppet::Type.type(:service).new(:name => "foostartbar", :provider => :upstart)
      provider = provider_class.new(resource)
      provider.stubs(:is_upstart?).returns(true)

      provider.expects(:status_exec).with(["foostartbar"]).returns("foostartbar stop/waiting")
      Process::Status.any_instance.stubs(:exitstatus).returns(0)
      provider.status.should == :stopped
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
          provider.send("#{command}cmd".to_sym).should == [provider.command(command.to_sym), resource.name]
        end
      end
      it "should return nil for the statuscmd" do
        provider.statuscmd.should be_nil
      end
    end

    describe "when init script" do
      before(:each) do
        provider.stubs(:is_upstart?).returns(false)
      end
      ["start", "stop", "status"].each do |command|
        it "should return the #{command}cmd of its parent provider" do
          provider.expects(:search).with('foo').returns("/etc/init.d/foo")
          provider.send("#{command}cmd".to_sym).should == ["/etc/init.d/foo", command.to_sym]
        end
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
          provider.should respond_to(enableable)
        end
      end

      describe "when enabling" do
        it "should open and uncomment the '#start on' line" do
          file = File.open(init_script, 'w')
          file.write(disabled_content)
          file.close
          provider.enable
          File.open(init_script).read.should == enabled_content
        end

        it "should add a 'start on' line if none exists" do
          file = File.open(init_script, 'w')
          file.write("this is a file")
          file.close
          provider.enable
          File.open(init_script).read.should == "this is a file\nstart on runlevel [2,3,4,5]"
        end

        it "should handle multiline 'start on' stanzas" do
          file = File.open(init_script, 'w')
          file.write(multiline_disabled)
          file.close
          provider.enable
          File.open(init_script).read.should == multiline_enabled
        end
      end

      describe "when disabling" do
        it "should open and comment the 'start on' line" do
          file = File.open(init_script, 'w')
          file.write(enabled_content)
          file.close
          provider.disable
          File.open(init_script).read.should == "#" + enabled_content
        end

        it "should handle multiline 'start on' stanzas" do
          file = File.open(init_script, 'w')
          file.write(multiline_enabled)
          file.close
          provider.disable
          File.open(init_script).read.should == multiline_disabled
        end
      end

      describe "when checking whether it is enabled" do
        it "should consider 'start on ...' to be enabled" do
          file = File.open(init_script, 'w')
          file.write(enabled_content)
          file.close
          provider.enabled?.should == :true
        end

        it "should consider '#start on ...' to be disabled" do
          file = File.open(init_script, 'w')
          file.write(disabled_content)
          file.close
          provider.enabled?.should == :false
        end

        it "should consider no start on line to be disabled" do
          file = File.open(init_script, 'w')
          file.write(content)
          file.close
          provider.enabled?.should == :false
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
          provider.should respond_to(enableable)
        end
      end

      describe "when enabling" do
        it "should open and uncomment the '#start on' line" do
          file = File.open(init_script, 'w')
          file.write(disabled_content)
          file.close
          provider.enable
          File.open(init_script).read.should == enabled_content
        end

        it "should add a 'start on' line if none exists" do
          file = File.open(init_script, 'w')
          file.write("this is a file")
          file.close
          provider.enable
          File.open(init_script).read.should == "this is a file\nstart on runlevel [2,3,4,5]"
        end

        it "should handle multiline 'start on' stanzas" do
          file = File.open(init_script, 'w')
          file.write(multiline_disabled)
          file.close
          provider.enable
          File.open(init_script).read.should == multiline_enabled
        end

        it "should remove manual stanzas" do
          file = File.open(init_script, 'w')
          file.write(multiline_enabled + "\nmanual")
          file.close
          provider.enable
          File.open(init_script).read.should == multiline_enabled + "\n"
        end
      end

      describe "when disabling" do
        it "should add a manual stanza" do
          file = File.open(init_script, 'w')
          file.write(enabled_content)
          file.close
          provider.disable
          File.open(init_script).read.should == enabled_content + "\nmanual"
        end

        it "should remove manual stanzas before adding new ones" do
          file = File.open(init_script, 'w')
          file.write(multiline_enabled + "\nmanual\n" + multiline_enabled)
          file.close
          provider.disable
          File.open(init_script).read.should == multiline_enabled + "\n" + multiline_enabled + "\nmanual"
        end

        it "should handle multiline 'start on' stanzas" do
          file = File.open(init_script, 'w')
          file.write(multiline_enabled)
          file.close
          provider.disable
          File.open(init_script).read.should == multiline_enabled + "\nmanual"
        end
      end

      describe "when checking whether it is enabled" do
        describe "with no manual stanza" do
          it "should consider 'start on ...' to be enabled" do
            file = File.open(init_script, 'w')
            file.write(enabled_content)
            file.close
            provider.enabled?.should == :true
          end

          it "should consider '#start on ...' to be disabled" do
            file = File.open(init_script, 'w')
            file.write(disabled_content)
            file.close
            provider.enabled?.should == :false
          end

          it "should consider no start on line to be disabled" do
            file = File.open(init_script, 'w')
            file.write(content)
            file.close
            provider.enabled?.should == :false
          end
        end

        describe "with manual stanza" do
          it "should consider 'start on ...' to be disabled if there is a trailing manual stanza" do
            file = File.open(init_script, 'w')
            file.write(enabled_content + "\nmanual\nother stuff")
            file.close
            provider.enabled?.should == :false
          end

          it "should consider two start on lines with a manual in the middle to be enabled" do
            file = File.open(init_script, 'w')
            file.write(enabled_content + "\nmanual\n" + enabled_content)
            file.close
            provider.enabled?.should == :true
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
          provider.should respond_to(enableable)
        end
      end

      describe "when enabling" do
        it "should add a 'start on' line if none exists" do
          file = File.open(init_script, 'w')
          file.write("this is a file")
          file.close
          provider.enable
          File.open(init_script).read.should == "this is a file"
          File.open(over_script).read.should == "\nstart on runlevel [2,3,4,5]"
        end

        it "should handle multiline 'start on' stanzas" do
          file = File.open(init_script, 'w')
          file.write(multiline_disabled)
          file.close
          provider.enable
          File.open(init_script).read.should == multiline_disabled
          File.open(over_script).read.should == "\nstart on runlevel [2,3,4,5]"
        end

        it "should remove any manual stanzas from the override file" do
          file = File.open(over_script, 'w')
          file.write("\nmanual")
          file.close
          file = File.open(init_script, 'w')
          file.write(enabled_content)
          file.close
          provider.enable
          File.open(init_script).read.should == enabled_content
          File.open(over_script).read.should == ""
        end

        it "should copy existing start on from conf file if conf file is disabled" do
          file = File.open(init_script, 'w')
          file.write(multiline_enabled_standalone + "\nmanual")
          file.close
          provider.enable
          File.open(init_script).read.should == multiline_enabled_standalone + "\nmanual"
          File.open(over_script).read.should == multiline_enabled_standalone
        end
      end

      describe "when disabling" do
        it "should add a manual stanza to the override file" do
          file = File.open(init_script, 'w')
          file.write(enabled_content)
          file.close
          provider.disable
          File.open(init_script).read.should == enabled_content
          File.open(over_script).read.should == "\nmanual"
        end

        it "should handle multiline 'start on' stanzas" do
          file = File.open(init_script, 'w')
          file.write(multiline_enabled)
          file.close
          provider.disable
          File.open(init_script).read.should == multiline_enabled
          File.open(over_script).read.should == "\nmanual"
        end
      end

      describe "when checking whether it is enabled" do
        describe "with no override file" do
          it "should consider 'start on ...' to be enabled" do
            file = File.open(init_script, 'w')
            file.write(enabled_content)
            file.close
            provider.enabled?.should == :true
          end

          it "should consider '#start on ...' to be disabled" do
            file = File.open(init_script, 'w')
            file.write(disabled_content)
            file.close
            provider.enabled?.should == :false
          end

          it "should consider no start on line to be disabled" do
            file = File.open(init_script, 'w')
            file.write(content)
            file.close
            provider.enabled?.should == :false
          end
        end
        describe "with override file" do
          it "should consider 'start on ...' to be disabled if there is manual in override file" do
            file = File.open(init_script, 'w')
            file.write(enabled_content)
            file.close
            file = File.open(over_script, 'w')
            file.write("\nmanual\nother stuff")
            file.close
            provider.enabled?.should == :false
          end

          it "should consider '#start on ...' to be enabled if there is a start on in the override file" do
            file = File.open(init_script, 'w')
            file.write(disabled_content)
            file.close
            file = File.open(over_script, 'w')
            file.write("start on stuff")
            file.close
            provider.enabled?.should == :true
          end
        end
      end
    end
  end
end
