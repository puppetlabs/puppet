#!/usr/bin/env rspec
require 'spec_helper'

provider_class = Puppet::Type.type(:zpool).provider(:solaris)

describe provider_class do
  before do
    @resource = stub("resource", :name => "mypool")
    @resource.stubs(:[]).returns "shouldvalue"
    @provider = provider_class.new(@resource)
  end

  describe "when getting the instance" do
    it "should call process_zpool_data with the result of get_pool_data only once" do
      @provider.stubs(:get_pool_data).returns(["foo", "disk"])
      @provider.expects(:process_zpool_data).with(["foo", "disk"]).returns("stuff").once
      @provider.current_pool
      @provider.current_pool
    end
  end

  describe "when calling flush" do
    it "should need to reload the pool" do
      @provider.stubs(:get_pool_data)
      @provider.expects(:process_zpool_data).returns("stuff").times(2)
      @provider.current_pool
      @provider.flush
      @provider.current_pool
    end
  end

  describe "when procesing zpool data" do
    before do
      @zpool_data = ["foo", "disk"]
    end

    describe "when there is no data" do
      it "should return a hash with ensure=>:absent" do
        @provider.process_zpool_data([])[:ensure].should == :absent
      end
    end

    describe "when there is a spare" do
      it "should add the spare disk to the hash" do
        @zpool_data += ["spares", "spare_disk"]
        @provider.process_zpool_data(@zpool_data)[:spare].should == ["spare_disk"]
      end
    end

    describe "when there are two spares" do
      it "should add the spare disk to the hash as a single string" do
        @zpool_data += ["spares", "spare_disk", "spare_disk2"]
        @provider.process_zpool_data(@zpool_data)[:spare].should == ["spare_disk spare_disk2"]
      end
    end

    describe "when there is a log" do
      it "should add the log disk to the hash" do
        @zpool_data += ["logs", "log_disk"]
        @provider.process_zpool_data(@zpool_data)[:log].should == ["log_disk"]
      end
    end

    describe "when there are two logs" do
      it "should add the log disks to the hash as a single string" do
        @zpool_data += ["spares", "spare_disk", "spare_disk2"]
        @provider.process_zpool_data(@zpool_data)[:spare].should == ["spare_disk spare_disk2"]
      end
    end

    describe "when the vdev is a single mirror" do
      it "should call create_multi_array with mirror" do
        @zpool_data = ["mirrorpool", "mirror", "disk1", "disk2"]
        @provider.process_zpool_data(@zpool_data)[:mirror].should == ["disk1 disk2"]
      end
    end

    describe "when the vdev is a single mirror on solaris 10u9 or later" do
      it "should call create_multi_array with mirror" do
        @zpool_data = ["mirrorpool", "mirror-0", "disk1", "disk2"]
        @provider.process_zpool_data(@zpool_data)[:mirror].should == ["disk1 disk2"]
      end
    end

    describe "when the vdev is a double mirror" do
      it "should call create_multi_array with mirror" do
        @zpool_data = ["mirrorpool", "mirror", "disk1", "disk2", "mirror", "disk3", "disk4"]
        @provider.process_zpool_data(@zpool_data)[:mirror].should == ["disk1 disk2", "disk3 disk4"]
      end
    end

    describe "when the vdev is a double mirror on solaris 10u9 or later" do
      it "should call create_multi_array with mirror" do
        @zpool_data = ["mirrorpool", "mirror-0", "disk1", "disk2", "mirror-1", "disk3", "disk4"]
        @provider.process_zpool_data(@zpool_data)[:mirror].should == ["disk1 disk2", "disk3 disk4"]
      end
    end

    describe "when the vdev is a raidz1" do
      it "should call create_multi_array with raidz1" do
        @zpool_data = ["mirrorpool", "raidz1", "disk1", "disk2"]
        @provider.process_zpool_data(@zpool_data)[:raidz].should == ["disk1 disk2"]
      end
    end

    describe "when the vdev is a raidz1 on solaris 10u9 or later" do
      it "should call create_multi_array with raidz1" do
        @zpool_data = ["mirrorpool", "raidz1-0", "disk1", "disk2"]
        @provider.process_zpool_data(@zpool_data)[:raidz].should == ["disk1 disk2"]
      end
    end

    describe "when the vdev is a raidz2" do
      it "should call create_multi_array with raidz2 and set the raid_parity" do
        @zpool_data = ["mirrorpool", "raidz2", "disk1", "disk2"]
        pool = @provider.process_zpool_data(@zpool_data)
        pool[:raidz].should == ["disk1 disk2"]
        pool[:raid_parity].should == "raidz2"
      end
    end

    describe "when the vdev is a raidz2 on solaris 10u9 or later" do
      it "should call create_multi_array with raidz2 and set the raid_parity" do
        @zpool_data = ["mirrorpool", "raidz2-0", "disk1", "disk2"]
        pool = @provider.process_zpool_data(@zpool_data)
        pool[:raidz].should == ["disk1 disk2"]
        pool[:raid_parity].should == "raidz2"
      end
    end
  end

  describe "when calling the getters and setters" do
    [:disk, :mirror, :raidz, :log, :spare].each do |field|
      describe "when calling #{field}" do
        it "should get the #{field} value from the current_pool hash" do
          pool_hash = mock "pool hash"
          pool_hash.expects(:[]).with(field)
          @provider.stubs(:current_pool).returns(pool_hash)
          @provider.send(field)
        end
      end

      describe "when setting the #{field}" do
        it "should warn the #{field} values were not in sync" do
          Puppet.expects(:warning).with("NO CHANGES BEING MADE: zpool #{field} does not match, should be 'shouldvalue' currently is 'currentvalue'")
          @provider.stubs(:current_pool).returns(Hash.new("currentvalue"))
          @provider.send((field.to_s + "=").intern, "shouldvalue")
        end
      end
    end
  end

  describe "when calling create", :'fails_on_ruby_1.9.2' => true do
    before do
      @resource.stubs(:[]).with(:pool).returns("mypool")
      @provider.stubs(:zpool)
    end


    it "should call build_vdevs" do
      @provider.expects(:build_vdevs).returns([])
      @provider.create
    end

    it "should call build_named with 'spares' and 'log" do
      @provider.expects(:build_named).with("spare").returns([])
      @provider.expects(:build_named).with("log").returns([])
      @provider.create
    end

    it "should call zpool with arguments from build_vdevs and build_named" do
      @provider.expects(:zpool).with(:create, 'mypool', 'shouldvalue', 'spare', 'shouldvalue', 'log', 'shouldvalue')
      @provider.create
    end
  end

  describe "when calling delete" do
    it "should call zpool with destroy and the pool name" do
      @resource.stubs(:[]).with(:pool).returns("poolname")
      @provider.expects(:zpool).with(:destroy, "poolname")
      @provider.delete
    end
  end

  describe "when calling exists?" do
    before do
      @current_pool = Hash.new(:absent)
      @provider.stubs(:get_pool_data).returns([])
      @provider.stubs(:process_zpool_data).returns(@current_pool)
    end

    it "should get the current pool" do
      @provider.expects(:process_zpool_data).returns(@current_pool)
      @provider.exists?
    end

    it "should return false if the current_pool is absent" do
      #the before sets it up
      @provider.exists?.should == false
    end

    it "should return true if the current_pool has values" do
      @current_pool[:pool] = "mypool"
      @provider.exists?.should == true
    end
  end

end
