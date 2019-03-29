require 'spec_helper'

require 'puppet/provider/mount'

describe Puppet::Provider::Mount do
  before :each do
    @mounter = Object.new
    @mounter.extend(Puppet::Provider::Mount)

    @name = "/"

    @resource = double('resource')
    allow(@resource).to receive(:[]).with(:name).and_return(@name)

    allow(@mounter).to receive(:resource).and_return(@resource)
  end

  describe Puppet::Provider::Mount, " when mounting" do
    before :each do
      allow(@mounter).to receive(:get).with(:ensure).and_return(:mounted)
    end

    it "should use the 'mountcmd' method to mount" do
      allow(@mounter).to receive(:options).and_return(nil)
      expect(@mounter).to receive(:mountcmd)

      @mounter.mount
    end

    it "should add the options following '-o' on MacOS if they exist and are not set to :absent" do
      expect(Facter).to receive(:value).with(:kernel).and_return('Darwin')
      allow(@mounter).to receive(:options).and_return("ro")
      expect(@mounter).to receive(:mountcmd).with('-o', 'ro', '/')

      @mounter.mount
    end

    it "should not explicitly pass mount options on systems other than MacOS" do
      expect(Facter).to receive(:value).with(:kernel).and_return('HP-UX')
      allow(@mounter).to receive(:options).and_return("ro")
      expect(@mounter).to receive(:mountcmd).with('/')

      @mounter.mount
    end

    it "should specify the filesystem name to the mount command" do
      allow(@mounter).to receive(:options).and_return(nil)
      expect(@mounter).to receive(:mountcmd) { |*ary| expect(ary[-1]).to eq(@name) }

      @mounter.mount
    end

    it "should update the :ensure state to :mounted if it was :unmounted before" do
      expect(@mounter).to receive(:mountcmd)
      allow(@mounter).to receive(:options).and_return(nil)
      expect(@mounter).to receive(:get).with(:ensure).and_return(:unmounted)
      expect(@mounter).to receive(:set).with(:ensure => :mounted)
      @mounter.mount
    end

    it "should update the :ensure state to :ghost if it was :absent before" do
      expect(@mounter).to receive(:mountcmd)
      allow(@mounter).to receive(:options).and_return(nil)
      expect(@mounter).to receive(:get).with(:ensure).and_return(:absent)
      expect(@mounter).to receive(:set).with(:ensure => :ghost)
      @mounter.mount
    end
  end

  describe Puppet::Provider::Mount, " when remounting" do
    context "if the resource supports remounting" do
      context "given explicit options on AIX" do
        it "should combine the options with 'remount'" do
          allow(@mounter).to receive(:info)
          allow(@mounter).to receive(:options).and_return('ro')
          allow(@resource).to receive(:[]).with(:remounts).and_return(:true)
          expect(Facter).to receive(:value).with(:operatingsystem).and_return('AIX')
          expect(@mounter).to receive(:mountcmd).with("-o", "ro,remount", @name)
          @mounter.remount
        end
      end

      it "should use '-o remount'" do
        allow(@mounter).to receive(:info)
        allow(@resource).to receive(:[]).with(:remounts).and_return(:true)
        expect(@mounter).to receive(:mountcmd).with("-o", "remount", @name)
        @mounter.remount
      end
    end

    it "should mount with '-o update' on OpenBSD" do
      allow(@mounter).to receive(:info)
      allow(@mounter).to receive(:options)
      allow(@resource).to receive(:[]).with(:remounts).and_return(false)
      expect(Facter).to receive(:value).with(:operatingsystem).and_return('OpenBSD')
      expect(@mounter).to receive(:mountcmd).with("-o", "update", @name)
      @mounter.remount
    end

    it "should unmount and mount if the resource does not specify it supports remounting" do
      allow(@mounter).to receive(:info)
      allow(@mounter).to receive(:options)
      allow(@resource).to receive(:[]).with(:remounts).and_return(false)
      expect(Facter).to receive(:value).with(:operatingsystem).and_return('AIX')
      expect(@mounter).to receive(:mount)
      expect(@mounter).to receive(:unmount)
      @mounter.remount
    end

    it "should log that it is remounting" do
      allow(@resource).to receive(:[]).with(:remounts).and_return(:true)
      allow(@mounter).to receive(:mountcmd)
      expect(@mounter).to receive(:info).with("Remounting")
      @mounter.remount
    end
  end

  describe Puppet::Provider::Mount, " when unmounting" do
    before :each do
      allow(@mounter).to receive(:get).with(:ensure).and_return(:unmounted)
    end

    it "should call the :umount command with the resource name" do
      expect(@mounter).to receive(:umount).with(@name)
      @mounter.unmount
    end

    it "should update the :ensure state to :absent if it was :ghost before" do
      expect(@mounter).to receive(:umount).with(@name).and_return(true)
      expect(@mounter).to receive(:get).with(:ensure).and_return(:ghost)
      expect(@mounter).to receive(:set).with(:ensure => :absent)
      @mounter.unmount
    end

    it "should update the :ensure state to :unmounted if it was :mounted before" do
      expect(@mounter).to receive(:umount).with(@name).and_return(true)
      expect(@mounter).to receive(:get).with(:ensure).and_return(:mounted)
      expect(@mounter).to receive(:set).with(:ensure => :unmounted)
      @mounter.unmount
    end
  end

  describe Puppet::Provider::Mount, " when determining if it is mounted" do
    it "should query the property_hash" do
      expect(@mounter).to receive(:get).with(:ensure).and_return(:mounted)
      @mounter.mounted?
    end

    it "should return true if prefetched value is :mounted" do
      allow(@mounter).to receive(:get).with(:ensure).and_return(:mounted)
      @mounter.mounted? == true
    end

    it "should return true if prefetched value is :ghost" do
      allow(@mounter).to receive(:get).with(:ensure).and_return(:ghost)
      @mounter.mounted? == true
    end

    it "should return false if prefetched value is :absent" do
      allow(@mounter).to receive(:get).with(:ensure).and_return(:absent)
      @mounter.mounted? == false
    end

    it "should return false if prefetched value is :unmounted" do
      allow(@mounter).to receive(:get).with(:ensure).and_return(:unmounted)
      @mounter.mounted? == false
    end
  end
end
