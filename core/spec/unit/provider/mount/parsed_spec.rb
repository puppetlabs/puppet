#! /usr/bin/env ruby
require 'spec_helper'
require 'shared_behaviours/all_parsedfile_providers'

describe Puppet::Type.type(:mount).provider(:parsed), :unless => Puppet.features.microsoft_windows? do

  let :vfstab_sample do
    "/dev/dsk/c0d0s0 /dev/rdsk/c0d0s0 \t\t    /  \t    ufs     1 no\t-"
  end

  let :fstab_sample do
    "/dev/vg00/lv01\t/spare   \t  \t   ext3    defaults\t1 2"
  end

  # LAK:FIXME I can't mock Facter because this test happens at parse-time.
  it "should default to /etc/vfstab on Solaris" do
    pending "This test only works on Solaris" unless Facter.value(:osfamily) == 'Solaris'
    described_class.default_target.should == '/etc/vfstab'
  end

  it "should default to /etc/fstab on anything else" do
    pending "This test does not work on Solaris" if Facter.value(:osfamily) == 'Solaris'
    described_class.default_target.should == '/etc/fstab'
  end

  describe "when parsing a line" do
    it "should not crash on incomplete lines in fstab" do
      parse = described_class.parse <<-FSTAB
/dev/incomplete
/dev/device       name
FSTAB
      expect { described_class.to_line(parse[0]) }.to_not raise_error
    end

#   it_should_behave_like "all parsedfile providers",
#     provider_class, my_fixtures('*.fstab')

    describe "on Solaris", :if => Facter.value(:osfamily) == 'Solaris' do
      it "should extract device from the first field" do
        described_class.parse_line(vfstab_sample)[:device].should == '/dev/dsk/c0d0s0'
      end

      it "should extract blockdevice from second field" do
        described_class.parse_line(vfstab_sample)[:blockdevice].should == "/dev/rdsk/c0d0s0"
      end

      it "should extract name from third field" do
        described_class.parse_line(vfstab_sample)[:name].should == "/"
      end

      it "should extract fstype from fourth field" do
        described_class.parse_line(vfstab_sample)[:fstype].should == "ufs"
      end

      it "should extract pass from fifth field" do
        described_class.parse_line(vfstab_sample)[:pass].should == "1"
      end

      it "should extract atboot from sixth field" do
        described_class.parse_line(vfstab_sample)[:atboot].should == "no"
      end

      it "should extract options from seventh field" do
        described_class.parse_line(vfstab_sample)[:options].should == "-"
      end
    end

    describe "on other platforms than Solaris", :if => Facter.value(:osfamily) != 'Solaris' do
      it "should extract device from the first field" do
        described_class.parse_line(fstab_sample)[:device].should == '/dev/vg00/lv01'
      end

      it "should extract name from second field" do
        described_class.parse_line(fstab_sample)[:name].should == "/spare"
      end

      it "should extract fstype from third field" do
        described_class.parse_line(fstab_sample)[:fstype].should == "ext3"
      end

      it "should extract options from fourth field" do
        described_class.parse_line(fstab_sample)[:options].should == "defaults"
      end

      it "should extract dump from fifth field" do
        described_class.parse_line(fstab_sample)[:dump].should == "1"
      end

      it "should extract options from sixth field" do
        described_class.parse_line(fstab_sample)[:pass].should == "2"
      end
    end

  end

  describe "mountinstances" do
    it "should get name from mountoutput found on Solaris" do
      Facter.stubs(:value).with(:osfamily).returns 'Solaris'
      described_class.stubs(:mountcmd).returns(File.read(my_fixture('solaris.mount')))
      mounts = described_class.mountinstances
      mounts.size.should == 6
      mounts[0].should == { :name => '/', :mounted => :yes }
      mounts[1].should == { :name => '/proc', :mounted => :yes }
      mounts[2].should == { :name => '/etc/mnttab', :mounted => :yes }
      mounts[3].should == { :name => '/tmp', :mounted => :yes }
      mounts[4].should == { :name => '/export/home', :mounted => :yes }
      mounts[5].should == { :name => '/ghost', :mounted => :yes }
    end

    it "should get name from mountoutput found on HP-UX" do
      Facter.stubs(:value).with(:osfamily).returns 'HP-UX'
      described_class.stubs(:mountcmd).returns(File.read(my_fixture('hpux.mount')))
      mounts = described_class.mountinstances
      mounts.size.should == 17
      mounts[0].should == { :name => '/', :mounted => :yes }
      mounts[1].should == { :name => '/devices', :mounted => :yes }
      mounts[2].should == { :name => '/dev', :mounted => :yes }
      mounts[3].should == { :name => '/system/contract', :mounted => :yes }
      mounts[4].should == { :name => '/proc', :mounted => :yes }
      mounts[5].should == { :name => '/etc/mnttab', :mounted => :yes }
      mounts[6].should == { :name => '/etc/svc/volatile', :mounted => :yes }
      mounts[7].should == { :name => '/system/object', :mounted => :yes }
      mounts[8].should == { :name => '/etc/dfs/sharetab', :mounted => :yes }
      mounts[9].should == { :name => '/lib/libc.so.1', :mounted => :yes }
      mounts[10].should == { :name => '/dev/fd', :mounted => :yes }
      mounts[11].should == { :name => '/tmp', :mounted => :yes }
      mounts[12].should == { :name => '/var/run', :mounted => :yes }
      mounts[13].should == { :name => '/export', :mounted => :yes }
      mounts[14].should == { :name => '/export/home', :mounted => :yes }
      mounts[15].should == { :name => '/rpool', :mounted => :yes }
      mounts[16].should == { :name => '/ghost', :mounted => :yes }
    end

    it "should get name from mountoutput found on Darwin" do
      Facter.stubs(:value).with(:osfamily).returns 'Darwin'
      described_class.stubs(:mountcmd).returns(File.read(my_fixture('darwin.mount')))
      mounts = described_class.mountinstances
      mounts.size.should == 6
      mounts[0].should == { :name => '/', :mounted => :yes }
      mounts[1].should == { :name => '/dev', :mounted => :yes }
      mounts[2].should == { :name => '/net', :mounted => :yes }
      mounts[3].should == { :name => '/home', :mounted => :yes }
      mounts[4].should == { :name => '/usr', :mounted => :yes }
      mounts[5].should == { :name => '/ghost', :mounted => :yes }
    end

    it "should get name from mountoutput found on Linux" do
      Facter.stubs(:value).with(:osfamily).returns 'Gentoo'
      described_class.stubs(:mountcmd).returns(File.read(my_fixture('linux.mount')))
      mounts = described_class.mountinstances
      mounts[0].should == { :name => '/', :mounted => :yes }
      mounts[1].should == { :name => '/lib64/rc/init.d', :mounted => :yes }
      mounts[2].should == { :name => '/sys', :mounted => :yes }
      mounts[3].should == { :name => '/usr/portage', :mounted => :yes }
      mounts[4].should == { :name => '/ghost', :mounted => :yes }
    end

    it "should get name from mountoutput found on AIX" do
      Facter.stubs(:value).with(:osfamily).returns 'AIX'
      described_class.stubs(:mountcmd).returns(File.read(my_fixture('aix.mount')))
      mounts = described_class.mountinstances
      mounts[0].should == { :name => '/', :mounted => :yes }
      mounts[1].should == { :name => '/tmp', :mounted => :yes }
      mounts[2].should == { :name => '/home', :mounted => :yes }
      mounts[3].should == { :name => '/usr', :mounted => :yes }
      mounts[4].should == { :name => '/usr/code', :mounted => :yes }
    end

    it "should raise an error if a line is not understandable" do
      described_class.stubs(:mountcmd).returns("bazinga!")
      expect { described_class.mountinstances }.to raise_error Puppet::Error, 'Could not understand line bazinga! from mount output'
    end

  end

  it "should support AIX's paragraph based /etc/filesystems"

  my_fixtures('*.fstab').each do |fstab|
    platform = File.basename(fstab, '.fstab')

    describe "when calling instances on #{platform}" do
      before :each do
        if Facter[:osfamily] == "Solaris" then
          platform == 'solaris' or
            pending "We need to stub the operatingsystem fact at load time, but can't"
        else
          platform != 'solaris' or
            pending "We need to stub the operatingsystem fact at load time, but can't"
        end

        # Stub the mount output to our fixture.
        begin
          mount = my_fixture(platform + '.mount')
          described_class.stubs(:mountcmd).returns File.read(mount)
        rescue
          pending "is #{platform}.mount missing at this point?"
        end

        # Note: we have to stub default_target before creating resources
        # because it is used by Puppet::Type::Mount.new to populate the
        # :target property.
        described_class.stubs(:default_target).returns fstab
        @retrieve = described_class.instances.collect { |prov| {:name => prov.get(:name), :ensure => prov.get(:ensure)}}
      end

      # Following mountpoint are present in all fstabs/mountoutputs
      it "should include unmounted resources" do
        pending("Solaris:Unable to stub Operating System Fact at runtime", :if => Facter.value(:osfamily) == 'Solaris' )
        @retrieve.should include(:name => '/', :ensure => :mounted)
      end

      it "should include mounted resources" do
        pending("Solaris:Unable to stub Operating System Fact at runtime", :if => Facter.value(:osfamily) == "Solaris")
        @retrieve.should include(:name => '/boot', :ensure => :unmounted)
      end

      it "should include ghost resources" do
        pending("Solaris:Unable to stub Operating System Fact at runtime", :if => Facter.value(:osfamily) == "Solaris")
        @retrieve.should include(:name => '/ghost', :ensure => :ghost)
      end

    end

    describe "when prefetching on #{platform}" do
      before :each do
        if Facter[:osfamily] == "Solaris" then
          platform == 'solaris' or
            pending "We need to stub the operatingsystem fact at load time, but can't"
        else
          platform != 'solaris' or
            pending "We need to stub the operatingsystem fact at load time, but can't"
        end

        # Stub the mount output to our fixture.
        begin
          mount = my_fixture(platform + '.mount')
          described_class.stubs(:mountcmd).returns File.read(mount)
        rescue
          pending "is #{platform}.mount missing at this point?"
        end

        # Note: we have to stub default_target before creating resources
        # because it is used by Puppet::Type::Mount.new to populate the
        # :target property.
        described_class.stubs(:default_target).returns fstab

        @res_ghost = Puppet::Type::Mount.new(:name => '/ghost')    # in no fake fstab
        @res_mounted = Puppet::Type::Mount.new(:name => '/')       # in every fake fstab
        @res_unmounted = Puppet::Type::Mount.new(:name => '/boot') # in every fake fstab
        @res_absent = Puppet::Type::Mount.new(:name => '/absent')  # in no fake fstab

        # Simulate transaction.rb:prefetch
        @resource_hash = {}
        [@res_ghost, @res_mounted, @res_unmounted, @res_absent].each do |resource|
          @resource_hash[resource.name] = resource
        end
      end

      it "should set :ensure to :unmounted if found in fstab but not mounted" do
        pending("Solaris:Unable to stub Operating System Fact at runtime", :if => Facter.value(:osfamily) == "Solaris")
        described_class.prefetch(@resource_hash)
        @res_unmounted.provider.get(:ensure).should == :unmounted
      end

      it "should set :ensure to :ghost if not found in fstab but mounted" do
        pending("Solaris:Unable to stub Operating System Fact at runtime", :if => Facter.value(:osfamily) == "Solaris")
        described_class.prefetch(@resource_hash)
        @res_ghost.provider.get(:ensure).should == :ghost
      end

      it "should set :ensure to :mounted if found in fstab and mounted" do
        pending("Solaris:Unable to stub Operating System Fact at runtime", :if => Facter.value(:osfamily) == "Solaris")
        described_class.prefetch(@resource_hash)
        @res_mounted.provider.get(:ensure).should == :mounted
      end

      it "should set :ensure to :absent if not found in fstab and not mounted" do
        described_class.prefetch(@resource_hash)
        @res_absent.provider.get(:ensure).should == :absent
      end
    end
  end
end
