#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:mount), :unless => Puppet.features.microsoft_windows? do

  before :each do
    Puppet::Type.type(:mount).stubs(:defaultprovider).returns providerclass
  end

  let :providerclass do
    described_class.provide(:fake_mount_provider) do
      attr_accessor :property_hash
      def create; end
      def destroy; end
      def exists?
        get(:ensure) != :absent
      end
      def mount; end
      def umount; end
      def mounted?
        [:mounted, :ghost].include?(get(:ensure))
      end
      mk_resource_methods
    end
  end

  let :provider do
    providerclass.new(:name => 'yay')
  end

  let :resource do
    described_class.new(:name => "yay", :audit => :ensure, :provider => provider)
  end

  let :ensureprop do
    resource.property(:ensure)
  end

  it "should have a :refreshable feature that requires the :remount method" do
    expect(described_class.provider_feature(:refreshable).methods).to eq([:remount])
  end

  it "should have no default value for :ensure" do
    mount = described_class.new(:name => "yay")
    expect(mount.should(:ensure)).to be_nil
  end

  it "should have :name as the only keyattribut" do
    expect(described_class.key_attributes).to eq([:name])
  end

  describe "when validating attributes" do
    [:name, :remounts, :provider].each do |param|
      it "should have a #{param} parameter" do
        expect(described_class.attrtype(param)).to eq(:param)
      end
    end

    [:ensure, :device, :blockdevice, :fstype, :options, :pass, :dump, :atboot, :target].each do |param|
      it "should have a #{param} property" do
        expect(described_class.attrtype(param)).to eq(:property)
      end
    end
  end

  describe "when validating values" do

    describe "for name" do
      it "should allow full qualified paths" do
        expect(described_class.new(:name => "/mnt/foo")[:name]).to eq('/mnt/foo')
      end

      it "should remove trailing slashes" do
        expect(described_class.new(:name => '/')[:name]).to eq('/')
        expect(described_class.new(:name => '//')[:name]).to eq('/')
        expect(described_class.new(:name => '/foo/')[:name]).to eq('/foo')
        expect(described_class.new(:name => '/foo/bar/')[:name]).to eq('/foo/bar')
        expect(described_class.new(:name => '/foo/bar/baz//')[:name]).to eq('/foo/bar/baz')
      end

      it "should not allow spaces" do
        expect { described_class.new(:name => "/mnt/foo bar") }.to raise_error Puppet::Error, /name.*whitespace/
      end

      it "should allow pseudo mountpoints (e.g. swap)" do
        expect(described_class.new(:name => 'none')[:name]).to eq('none')
      end
    end

    describe "for ensure" do
      it "should alias :present to :defined as a value to :ensure" do
        mount = described_class.new(:name => "yay", :ensure => :present)
        expect(mount.should(:ensure)).to eq(:defined)
      end

      it "should support :present as a value to :ensure" do
        expect { described_class.new(:name => "yay", :ensure => :present) }.to_not raise_error
      end

      it "should support :defined as a value to :ensure" do
        expect { described_class.new(:name => "yay", :ensure => :defined) }.to_not raise_error
      end

      it "should support :unmounted as a value to :ensure" do
        expect { described_class.new(:name => "yay", :ensure => :unmounted) }.to_not raise_error
      end

      it "should support :absent as a value to :ensure" do
        expect { described_class.new(:name => "yay", :ensure => :absent) }.to_not raise_error
      end

      it "should support :mounted as a value to :ensure" do
        expect { described_class.new(:name => "yay", :ensure => :mounted) }.to_not raise_error
      end

      it "should not support other values for :ensure" do
        expect { described_class.new(:name => "yay", :ensure => :mount) }.to raise_error Puppet::Error, /Invalid value/
      end
    end

    describe "for device" do
      it "should support normal /dev paths for device" do
        expect { described_class.new(:name => "/foo", :ensure => :present, :device => '/dev/hda1') }.to_not raise_error
        expect { described_class.new(:name => "/foo", :ensure => :present, :device => '/dev/dsk/c0d0s0') }.to_not raise_error
      end

      it "should support labels for device" do
        expect { described_class.new(:name => "/foo", :ensure => :present, :device => 'LABEL=/boot') }.to_not raise_error
        expect { described_class.new(:name => "/foo", :ensure => :present, :device => 'LABEL=SWAP-hda6') }.to_not raise_error
      end

      it "should support pseudo devices for device" do
        expect { described_class.new(:name => "/foo", :ensure => :present, :device => 'ctfs') }.to_not raise_error
        expect { described_class.new(:name => "/foo", :ensure => :present, :device => 'swap') }.to_not raise_error
        expect { described_class.new(:name => "/foo", :ensure => :present, :device => 'sysfs') }.to_not raise_error
        expect { described_class.new(:name => "/foo", :ensure => :present, :device => 'proc') }.to_not raise_error
      end

      it 'should not support whitespace in device' do
        expect { described_class.new(:name => "/foo", :ensure => :present, :device => '/dev/my dev/foo') }.to raise_error Puppet::Error, /device.*whitespace/
        expect { described_class.new(:name => "/foo", :ensure => :present, :device => "/dev/my\tdev/foo") }.to raise_error Puppet::Error, /device.*whitespace/
      end
    end

    describe "for blockdevice" do
      before :each do
        # blockdevice is only used on Solaris
        Facter.stubs(:value).with(:operatingsystem).returns 'Solaris'
        Facter.stubs(:value).with(:osfamily).returns 'Solaris'
      end

      it "should support normal /dev/rdsk paths for blockdevice" do
        expect { described_class.new(:name => "/foo", :ensure => :present, :blockdevice => '/dev/rdsk/c0d0s0') }.to_not raise_error
      end

      it "should support a dash for blockdevice" do
        expect { described_class.new(:name => "/foo", :ensure => :present, :blockdevice => '-') }.to_not raise_error
      end

      it "should not support whitespace in blockdevice" do
        expect { described_class.new(:name => "/foo", :ensure => :present, :blockdevice => '/dev/my dev/foo') }.to raise_error Puppet::Error, /blockdevice.*whitespace/
        expect { described_class.new(:name => "/foo", :ensure => :present, :blockdevice => "/dev/my\tdev/foo") }.to raise_error Puppet::Error, /blockdevice.*whitespace/
      end

      it "should default to /dev/rdsk/DEVICE if device is /dev/dsk/DEVICE" do
        obj = described_class.new(:name => "/foo", :device => '/dev/dsk/c0d0s0')
        expect(obj[:blockdevice]).to eq('/dev/rdsk/c0d0s0')
      end

      it "should default to - if it is an nfs-share" do
        obj = described_class.new(:name => "/foo", :device => "server://share", :fstype => 'nfs')
        expect(obj[:blockdevice]).to eq('-')
      end

      it "should have no default otherwise" do
        expect(described_class.new(:name => "/foo")[:blockdevice]).to eq(nil)
        expect(described_class.new(:name => "/foo", :device => "/foo")[:blockdevice]).to eq(nil)
      end

      it "should overwrite any default if blockdevice is explicitly set" do
        expect(described_class.new(:name => "/foo", :device => '/dev/dsk/c0d0s0', :blockdevice => '/foo')[:blockdevice]).to eq('/foo')
        expect(described_class.new(:name => "/foo", :device => "server://share", :fstype => 'nfs', :blockdevice => '/foo')[:blockdevice]).to eq('/foo')
      end
    end

    describe "for fstype" do
      it "should support valid fstypes" do
        expect { described_class.new(:name => "/foo", :ensure => :present, :fstype => 'ext3') }.to_not raise_error
        expect { described_class.new(:name => "/foo", :ensure => :present, :fstype => 'proc') }.to_not raise_error
        expect { described_class.new(:name => "/foo", :ensure => :present, :fstype => 'sysfs') }.to_not raise_error
      end

      it "should support auto as a special fstype" do
        expect { described_class.new(:name => "/foo", :ensure => :present, :fstype => 'auto') }.to_not raise_error
      end

      it "should not support whitespace in fstype" do
        expect { described_class.new(:name => "/foo", :ensure => :present, :fstype => 'ext 3') }.to raise_error Puppet::Error, /fstype.*whitespace/
      end

      it "should not support an empty string in fstype" do
        expect { described_class.new(:name => "/foo", :ensure => :present, :fstype => "") }.to raise_error Puppet::Error, /fstype.*empty string/
      end
    end

    describe "for options" do
      it "should support a single option" do
        expect { described_class.new(:name => "/foo", :ensure => :present, :options => 'ro') }.to_not raise_error
      end

      it "should support multiple options as a comma separated list" do
        expect { described_class.new(:name => "/foo", :ensure => :present, :options => 'ro,rsize=4096') }.to_not raise_error
      end

      it "should not support whitespace in options" do
        expect { described_class.new(:name => "/foo", :ensure => :present, :options => ['ro','foo bar','intr']) }.to raise_error Puppet::Error, /option.*whitespace/
      end

      it "should not support an empty string in options" do
        expect { described_class.new(:name => "/foo", :ensure => :present, :options => "") }.to raise_error Puppet::Error, /option.*empty string/
      end
    end

    describe "for pass" do
      it "should support numeric values" do
        expect { described_class.new(:name => "/foo", :ensure => :present, :pass => '0') }.to_not raise_error
        expect { described_class.new(:name => "/foo", :ensure => :present, :pass => '1') }.to_not raise_error
        expect { described_class.new(:name => "/foo", :ensure => :present, :pass => '2') }.to_not raise_error
      end

      it "should support - on Solaris" do
        Facter.stubs(:value).with(:operatingsystem).returns 'Solaris'
        Facter.stubs(:value).with(:osfamily).returns 'Solaris'
        expect { described_class.new(:name => "/foo", :ensure => :present, :pass => '-') }.to_not raise_error
      end

      it "should default to 0 on non Solaris" do
        Facter.stubs(:value).with(:osfamily).returns nil
        Facter.stubs(:value).with(:operatingsystem).returns 'HP-UX'
        expect(described_class.new(:name => "/foo", :ensure => :present)[:pass]).to eq(0)
      end

      it "should default to - on Solaris" do
        Facter.stubs(:value).with(:operatingsystem).returns 'Solaris'
        Facter.stubs(:value).with(:osfamily).returns 'Solaris'
        expect(described_class.new(:name => "/foo", :ensure => :present)[:pass]).to eq('-')
      end
    end

    describe "for dump" do
      it "should support 0 as a value for dump" do
        expect { described_class.new(:name => "/foo", :ensure => :present, :dump => '0') }.to_not raise_error
      end

      it "should support 1 as a value for dump" do
        expect { described_class.new(:name => "/foo", :ensure => :present, :dump => '1') }.to_not raise_error
      end

      # Unfortunately the operatingsystem is evaluatet at load time so I am unable to stub operatingsystem
      it "should support 2 as a value for dump on FreeBSD", :if => Facter.value(:operatingsystem) == 'FreeBSD' do
        expect { described_class.new(:name => "/foo", :ensure => :present, :dump => '2') }.to_not raise_error
      end

      it "should not support 2 as a value for dump when not on FreeBSD", :if => Facter.value(:operatingsystem) != 'FreeBSD' do
        expect { described_class.new(:name => "/foo", :ensure => :present, :dump => '2') }.to raise_error Puppet::Error, /Invalid value/
      end

      it "should default to 0" do
        expect(described_class.new(:name => "/foo", :ensure => :present)[:dump]).to eq(0)
      end
    end

    describe "for atboot" do
      it "does not allow non-boolean values" do
        expect { described_class.new(:name => "/foo", :ensure => :present, :atboot => 'unknown') }.to raise_error Puppet::Error, /expected a boolean value/
      end

      it "interprets yes as yes" do
        resource = described_class.new(:name => "/foo", :ensure => :present, :atboot => :yes)

        expect(resource[:atboot]).to eq(:yes)
      end

      it "interprets true as yes" do
        resource = described_class.new(:name => "/foo", :ensure => :present, :atboot => :true)

        expect(resource[:atboot]).to eq(:yes)
      end

      it "interprets no as no" do
        resource = described_class.new(:name => "/foo", :ensure => :present, :atboot => :no)

        expect(resource[:atboot]).to eq(:no)
      end

      it "interprets false as no" do
        resource = described_class.new(:name => "/foo", :ensure => :present, :atboot => false)

        expect(resource[:atboot]).to eq(:no)
      end
    end
  end


  describe "when changing the host" do
    def test_ensure_change(options)
      provider.set(:ensure => options[:from])
      provider.expects(:create).times(options[:create] || 0)
      provider.expects(:destroy).times(options[:destroy] || 0)
      provider.expects(:mount).never
      provider.expects(:unmount).times(options[:unmount] || 0)
      ensureprop.stubs(:syncothers)
      ensureprop.should = options[:to]
      ensureprop.sync
      expect(!!provider.property_hash[:needs_mount]).to eq(!!options[:mount])
    end

    it "should create itself when changing from :ghost to :present" do
      test_ensure_change(:from => :ghost, :to => :present, :create => 1)
    end

    it "should create itself when changing from :absent to :present" do
      test_ensure_change(:from => :absent, :to => :present, :create => 1)
    end

    it "should create itself and unmount when changing from :ghost to :unmounted" do
      test_ensure_change(:from => :ghost, :to => :unmounted, :create => 1, :unmount => 1)
    end

    it "should unmount resource when changing from :mounted to :unmounted" do
      test_ensure_change(:from => :mounted, :to => :unmounted, :unmount => 1)
    end

    it "should create itself when changing from :absent to :unmounted" do
      test_ensure_change(:from => :absent, :to => :unmounted, :create => 1)
    end

    it "should unmount resource when changing from :ghost to :absent" do
      test_ensure_change(:from => :ghost, :to => :absent, :unmount => 1)
    end

    it "should unmount and destroy itself when changing from :mounted to :absent" do
      test_ensure_change(:from => :mounted, :to => :absent, :destroy => 1, :unmount => 1)
    end

    it "should destroy itself when changing from :unmounted to :absent" do
      test_ensure_change(:from => :unmounted, :to => :absent, :destroy => 1)
    end

    it "should create itself when changing from :ghost to :mounted" do
      test_ensure_change(:from => :ghost, :to => :mounted, :create => 1)
    end

    it "should create itself and mount when changing from :absent to :mounted" do
      test_ensure_change(:from => :absent, :to => :mounted, :create => 1, :mount => 1)
    end

    it "should mount resource when changing from :unmounted to :mounted" do
      test_ensure_change(:from => :unmounted, :to => :mounted, :mount => 1)
    end


    it "should be in sync if it is :absent and should be :absent" do
      ensureprop.should = :absent
      expect(ensureprop.safe_insync?(:absent)).to eq(true)
    end

    it "should be out of sync if it is :absent and should be :defined" do
      ensureprop.should = :defined
      expect(ensureprop.safe_insync?(:absent)).to eq(false)
    end

    it "should be out of sync if it is :absent and should be :mounted" do
      ensureprop.should = :mounted
      expect(ensureprop.safe_insync?(:absent)).to eq(false)
    end

    it "should be out of sync if it is :absent and should be :unmounted" do
      ensureprop.should = :unmounted
      expect(ensureprop.safe_insync?(:absent)).to eq(false)
    end

    it "should be out of sync if it is :mounted and should be :absent" do
      ensureprop.should = :absent
      expect(ensureprop.safe_insync?(:mounted)).to eq(false)
    end

    it "should be in sync if it is :mounted and should be :defined" do
      ensureprop.should = :defined
      expect(ensureprop.safe_insync?(:mounted)).to eq(true)
    end

    it "should be in sync if it is :mounted and should be :mounted" do
      ensureprop.should = :mounted
      expect(ensureprop.safe_insync?(:mounted)).to eq(true)
    end

    it "should be out in sync if it is :mounted and should be :unmounted" do
      ensureprop.should = :unmounted
      expect(ensureprop.safe_insync?(:mounted)).to eq(false)
    end


    it "should be out of sync if it is :unmounted and should be :absent" do
      ensureprop.should = :absent
      expect(ensureprop.safe_insync?(:unmounted)).to eq(false)
    end

    it "should be in sync if it is :unmounted and should be :defined" do
      ensureprop.should = :defined
      expect(ensureprop.safe_insync?(:unmounted)).to eq(true)
    end

    it "should be out of sync if it is :unmounted and should be :mounted" do
      ensureprop.should = :mounted
      expect(ensureprop.safe_insync?(:unmounted)).to eq(false)
    end

    it "should be in sync if it is :unmounted and should be :unmounted" do
      ensureprop.should = :unmounted
      expect(ensureprop.safe_insync?(:unmounted)).to eq(true)
    end


    it "should be out of sync if it is :ghost and should be :absent" do
      ensureprop.should = :absent
      expect(ensureprop.safe_insync?(:ghost)).to eq(false)
    end

    it "should be out of sync if it is :ghost and should be :defined" do
      ensureprop.should = :defined
      expect(ensureprop.safe_insync?(:ghost)).to eq(false)
    end

    it "should be out of sync if it is :ghost and should be :mounted" do
      ensureprop.should = :mounted
      expect(ensureprop.safe_insync?(:ghost)).to eq(false)
    end

    it "should be out of sync if it is :ghost and should be :unmounted" do
      ensureprop.should = :unmounted
      expect(ensureprop.safe_insync?(:ghost)).to eq(false)
    end
  end

  describe "when responding to refresh" do
    pending "2.6.x specifies slightly different behavior and the desired behavior needs to be clarified and revisited.  See ticket #4904" do
      it "should remount if it is supposed to be mounted" do
        resource[:ensure] = "mounted"
        provider.expects(:remount)

        resource.refresh
      end

      it "should not remount if it is supposed to be present" do
        resource[:ensure] = "present"
        provider.expects(:remount).never

        resource.refresh
      end

      it "should not remount if it is supposed to be absent" do
        resource[:ensure] = "absent"
        provider.expects(:remount).never

        resource.refresh
      end

      it "should not remount if it is supposed to be defined" do
        resource[:ensure] = "defined"
        provider.expects(:remount).never

        resource.refresh
      end

      it "should not remount if it is supposed to be unmounted" do
        resource[:ensure] = "unmounted"
        provider.expects(:remount).never

        resource.refresh
      end

      it "should not remount swap filesystems" do
        resource[:ensure] = "mounted"
        resource[:fstype] = "swap"
        provider.expects(:remount).never

        resource.refresh
      end
    end
  end

  describe "when modifying an existing mount entry" do

    let :initial_values do
      {
        :ensure      => :mounted,
        :name        => '/mnt/foo',
        :device      => "/foo/bar",
        :blockdevice => "/other/bar",
        :target      => "/what/ever",
        :options     => "soft",
        :pass        => 0,
        :dump        => 0,
        :atboot      => :no,
      }
    end


    let :resource do
      described_class.new(initial_values.merge(:provider => provider))
    end

    let :provider do
      providerclass.new(initial_values)
    end

    def run_in_catalog(*resources)
      Puppet::Util::Storage.stubs(:store)
      catalog = Puppet::Resource::Catalog.new
      catalog.add_resource(*resources)
      catalog.apply
    end

    it "should use the provider to change the dump value" do
      provider.expects(:dump=).with(1)

      resource[:dump] = 1

      run_in_catalog(resource)
    end

    it "should umount before flushing changes to disk" do
      syncorder = sequence('syncorder')

      provider.expects(:unmount).in_sequence(syncorder)
      provider.expects(:options=).in_sequence(syncorder).with 'hard'
      resource.expects(:flush).in_sequence(syncorder) # Call inside syncothers
      resource.expects(:flush).in_sequence(syncorder) # I guess transaction or anything calls flush again

      resource[:ensure] = :unmounted
      resource[:options] = 'hard'

      run_in_catalog(resource)
    end
  end

  describe "establishing autorequires and autobefores" do

    def create_mount_resource(path)
      described_class.new(
        :name => path,
        :provider => providerclass.new(path)
      )
    end

    def create_file_resource(path)
      file_class = Puppet::Type.type(:file)
      file_class.new(
        :path => path,
        :provider => file_class.new(:path => path).provider
      )
    end

    def create_catalog(*resources)
      catalog = Puppet::Resource::Catalog.new
      resources.each do |resource|
        catalog.add_resource resource
      end

      catalog
    end

    let(:root_mount) { create_mount_resource("/") }
    let(:var_mount)  { create_mount_resource("/var") }
    let(:log_mount)  { create_mount_resource("/var/log") }
    let(:var_file) { create_file_resource('/var') }
    let(:log_file) { create_file_resource('/var/log') }
    let(:puppet_file) { create_file_resource('/var/log/puppet') }
    let(:opt_file) { create_file_resource('/opt/var/puppet') }

    before do
      create_catalog(root_mount, var_mount, log_mount, var_file, log_file, puppet_file, opt_file)
    end

    it "adds no autorequires for the root mount" do
      expect(root_mount.autorequire).to be_empty
    end

    it "adds the parent autorequire and the file autorequire for a mount with one parent" do
      parent_relationship = var_mount.autorequire[0]

      expect(var_mount.autorequire).to have_exactly(1).item

      expect(parent_relationship.source).to eq root_mount
      expect(parent_relationship.target).to eq var_mount
    end

    it "adds both parent autorequires and the file autorequire for a mount with two parents" do
      grandparent_relationship = log_mount.autorequire[0]
      parent_relationship = log_mount.autorequire[1]

      expect(log_mount.autorequire).to have_exactly(2).items

      expect(grandparent_relationship.source).to eq root_mount
      expect(grandparent_relationship.target).to eq log_mount

      expect(parent_relationship.source).to eq var_mount
      expect(parent_relationship.target).to eq log_mount
    end

    it "adds the child autobefore for a mount with one file child" do
      child_relationship = log_mount.autobefore[0]

      expect(log_mount.autobefore).to have_exactly(1).item

      expect(child_relationship.source).to eq log_mount
      expect(child_relationship.target).to eq puppet_file
    end

    it "adds both child autobefores for a mount with two file children" do
      child_relationship = var_mount.autobefore[0]
      grandchild_relationship = var_mount.autobefore[1]

      expect(var_mount.autobefore).to have_exactly(2).items

      expect(child_relationship.source).to eq var_mount
      expect(child_relationship.target).to eq log_file

      expect(grandchild_relationship.source).to eq var_mount
      expect(grandchild_relationship.target).to eq puppet_file
    end
  end
end
