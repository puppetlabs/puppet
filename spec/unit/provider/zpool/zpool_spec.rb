#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:zpool).provider(:zpool) do
  let(:name) { 'mypool' }
  let(:zpool) { '/usr/sbin/zpool' }

  let(:resource) do
    Puppet::Type.type(:zpool).new(:name => name, :provider => :zpool)
  end

  let(:provider) { resource.provider }

  before do
    provider.class.stubs(:which).with('zpool').returns(zpool)
  end

  context '#current_pool' do
    it "should call process_zpool_data with the result of get_pool_data only once" do
      provider.stubs(:get_pool_data).returns(["foo", "disk"])
      provider.expects(:process_zpool_data).with(["foo", "disk"]).returns("stuff").once

      provider.current_pool
      provider.current_pool
    end
  end

  describe "self.instances" do
    it "should have an instances method" do
      expect(provider.class).to respond_to(:instances)
    end

    it "should list instances" do
      provider.class.expects(:zpool).with(:list,'-H').returns File.read(my_fixture('zpool-list.out'))
      instances = provider.class.instances.map { |p| {:name => p.get(:name), :ensure => p.get(:ensure)} }
      expect(instances.size).to eq(2)
      expect(instances[0]).to eq({:name => 'rpool', :ensure => :present})
      expect(instances[1]).to eq({:name => 'mypool', :ensure => :present})
    end
  end

  context '#flush' do
    it "should reload the pool" do
      provider.stubs(:get_pool_data)
      provider.expects(:process_zpool_data).returns("stuff").times(2)
      provider.current_pool
      provider.flush
      provider.current_pool
    end
  end

  context '#process_zpool_data' do
    let(:zpool_data) { ["foo", "disk"] }

    describe "when there is no data" do
      it "should return a hash with ensure=>:absent" do
        expect(provider.process_zpool_data([])[:ensure]).to eq(:absent)
      end
    end

    describe "when there is a spare" do
      it "should add the spare disk to the hash" do
        zpool_data.concat ["spares", "spare_disk"]
        expect(provider.process_zpool_data(zpool_data)[:spare]).to eq(["spare_disk"])
      end
    end

    describe "when there are two spares" do
      it "should add the spare disk to the hash as a single string" do
        zpool_data.concat ["spares", "spare_disk", "spare_disk2"]
        expect(provider.process_zpool_data(zpool_data)[:spare]).to eq(["spare_disk spare_disk2"])
      end
    end

    describe "when there is a log" do
      it "should add the log disk to the hash" do
        zpool_data.concat ["logs", "log_disk"]
        expect(provider.process_zpool_data(zpool_data)[:log]).to eq(["log_disk"])
      end
    end

    describe "when there are two logs" do
      it "should add the log disks to the hash as a single string" do
        zpool_data.concat ["spares", "spare_disk", "spare_disk2"]
        expect(provider.process_zpool_data(zpool_data)[:spare]).to eq(["spare_disk spare_disk2"])
      end
    end

    describe "when the vdev is a single mirror" do
      it "should call create_multi_array with mirror" do
        zpool_data = ["mirrorpool", "mirror", "disk1", "disk2"]
        expect(provider.process_zpool_data(zpool_data)[:mirror]).to eq(["disk1 disk2"])
      end
    end

    describe "when the vdev is a single mirror on solaris 10u9 or later" do
      it "should call create_multi_array with mirror" do
        zpool_data = ["mirrorpool", "mirror-0", "disk1", "disk2"]
        expect(provider.process_zpool_data(zpool_data)[:mirror]).to eq(["disk1 disk2"])
      end
    end

    describe "when the vdev is a double mirror" do
      it "should call create_multi_array with mirror" do
        zpool_data = ["mirrorpool", "mirror", "disk1", "disk2", "mirror", "disk3", "disk4"]
        expect(provider.process_zpool_data(zpool_data)[:mirror]).to eq(["disk1 disk2", "disk3 disk4"])
      end
    end

    describe "when the vdev is a double mirror on solaris 10u9 or later" do
      it "should call create_multi_array with mirror" do
        zpool_data = ["mirrorpool", "mirror-0", "disk1", "disk2", "mirror-1", "disk3", "disk4"]
        expect(provider.process_zpool_data(zpool_data)[:mirror]).to eq(["disk1 disk2", "disk3 disk4"])
      end
    end

    describe "when the vdev is a raidz1" do
      it "should call create_multi_array with raidz1" do
        zpool_data = ["mirrorpool", "raidz1", "disk1", "disk2"]
        expect(provider.process_zpool_data(zpool_data)[:raidz]).to eq(["disk1 disk2"])
      end
    end

    describe "when the vdev is a raidz1 on solaris 10u9 or later" do
      it "should call create_multi_array with raidz1" do
        zpool_data = ["mirrorpool", "raidz1-0", "disk1", "disk2"]
        expect(provider.process_zpool_data(zpool_data)[:raidz]).to eq(["disk1 disk2"])
      end
    end

    describe "when the vdev is a raidz2" do
      it "should call create_multi_array with raidz2 and set the raid_parity" do
        zpool_data = ["mirrorpool", "raidz2", "disk1", "disk2"]
        pool = provider.process_zpool_data(zpool_data)
        expect(pool[:raidz]).to eq(["disk1 disk2"])
        expect(pool[:raid_parity]).to eq("raidz2")
      end
    end

    describe "when the vdev is a raidz2 on solaris 10u9 or later" do
      it "should call create_multi_array with raidz2 and set the raid_parity" do
        zpool_data = ["mirrorpool", "raidz2-0", "disk1", "disk2"]
        pool = provider.process_zpool_data(zpool_data)
        expect(pool[:raidz]).to eq(["disk1 disk2"])
        expect(pool[:raid_parity]).to eq("raidz2")
      end
    end
  end

  describe "when calling the getters and setters" do
    [:disk, :mirror, :raidz, :log, :spare].each do |field|
      describe "when calling #{field}" do
        it "should get the #{field} value from the current_pool hash" do
          pool_hash = {}
          pool_hash[field] = 'value'
          provider.stubs(:current_pool).returns(pool_hash)

          expect(provider.send(field)).to eq('value')
        end
      end

      describe "when setting the #{field}" do
        it "should fail if readonly #{field} values change" do
          provider.stubs(:current_pool).returns(Hash.new("currentvalue"))
          expect {
            provider.send((field.to_s + "=").intern, "shouldvalue")
          }.to raise_error(Puppet::Error, /can\'t be changed/)
        end
      end
    end
  end

  context '#create' do
    context "when creating disks for a zpool" do
      before do
        resource[:disk] = "disk1"
      end

      it "should call create with the build_vdevs value" do
        provider.expects(:zpool).with(:create, name, 'disk1')
        provider.create
      end

      it "should call create with the 'spares' and 'log' values" do
        resource[:spare] = ['value1']
        resource[:log] = ['value2']
        provider.expects(:zpool).with(:create, name, 'disk1', 'spare', 'value1', 'log', 'value2')
        provider.create
      end
    end

    context "when creating mirrors for a zpool" do
      it "executes 'create' for a single group of mirrored devices" do
        resource[:mirror] = ["disk1 disk2"]
        provider.expects(:zpool).with(:create, name, 'mirror', 'disk1', 'disk2')
        provider.create
      end

      it "repeats the 'mirror' keyword between groups of mirrored devices" do
        resource[:mirror] = ["disk1 disk2", "disk3 disk4"]
        provider.expects(:zpool).with(:create, name, 'mirror', 'disk1', 'disk2', 'mirror', 'disk3', 'disk4')
        provider.create
      end
    end

    describe "when creating raidz for a zpool" do
      it "executes 'create' for a single raidz group" do
        resource[:raidz] = ["disk1 disk2"]
        provider.expects(:zpool).with(:create, name, 'raidz1', 'disk1', 'disk2')
        provider.create
      end

      it "execute 'create' for a single raidz2 group" do
        resource[:raidz] = ["disk1 disk2"]
        resource[:raid_parity] = 'raidz2'
        provider.expects(:zpool).with(:create, name, 'raidz2', 'disk1', 'disk2')
        provider.create
      end

      it "repeats the 'raidz1' keyword between each group of raidz devices" do
        resource[:raidz] = ["disk1 disk2", "disk3 disk4"]
        provider.expects(:zpool).with(:create, name, 'raidz1', 'disk1', 'disk2', 'raidz1', 'disk3', 'disk4')
        provider.create
      end
    end
  end

  context '#delete' do
    it "should call zpool with destroy and the pool name" do
      provider.expects(:zpool).with(:destroy, name)
      provider.destroy
    end
  end

  context '#exists?' do
    it "should get the current pool" do
      provider.expects(:current_pool).returns({:pool => 'somepool'})
      provider.exists?
    end

    it "should return false if the current_pool is absent" do
      provider.expects(:current_pool).returns({:pool => :absent})
      expect(provider).not_to be_exists
    end

    it "should return true if the current_pool has values" do
      provider.expects(:current_pool).returns({:pool => name})
      expect(provider).to be_exists
    end
  end
end
