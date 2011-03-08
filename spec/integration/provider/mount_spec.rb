require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/file_bucket/dipper'

describe "mount provider (integration)" do
  include PuppetSpec::Files

  before :each do
    @fake_fstab = tmpfile('fstab')
    File.open(@fake_fstab, 'w') do |f|
      # leave file empty
    end
    Puppet::Type.type(:mount).defaultprovider.stubs(:default_target).returns(@fake_fstab)
    Facter.stubs(:value).with(:operatingsystem).returns('Darwin')
    Puppet::Util::ExecutionStub.set do |command, options|
      case command[0]
      when %r{/s?bin/mount}
        if command.length == 1
          if @mounted
            "/dev/disk1s1 on /Volumes/foo_disk (msdos, local)\n"
          else
            ''
          end
        else
          command.length.should == 4
          command[1].should == '-o'
          command[2].should == 'local'
          command[3].should == '/Volumes/foo_disk'
          @mounted.should == false # verify that we don't try to call "mount" redundantly
          check_fstab
          @mounted = true
          ''
        end
      when %r{/s?bin/umount}
        fail "unexpected umount" unless @umount_permitted
        command.length.should == 2
        command[1].should == '/Volumes/foo_disk'
        @mounted = false
        ''
      else
        fail "Unexpected command #{command.inspect} executed"
      end
    end
  end

  after :each do
    Puppet::Type::Mount::ProviderParsed.clear # Work around bug #6628
  end

  def check_fstab
    # Verify that the fake fstab has the expected data in it
    File.read(@fake_fstab).lines.reject { |x| x =~ /^#/ }.should == ["/dev/disk1s1\t/Volumes/foo_disk\tmsdos\tlocal\t0\t0\n"]
  end

  def run_in_catalog(ensure_setting)
    resource = Puppet::Type.type(:mount).new(:name => "/Volumes/foo_disk", :ensure => ensure_setting,
                                             :device => "/dev/disk1s1", :options => "local", :fstype => "msdos")
    Puppet::FileBucket::Dipper.any_instance.stubs(:backup) # Don't backup to the filebucket
    resource.expects(:err).never
    catalog = Puppet::Resource::Catalog.new
    catalog.host_config = false # Stop Puppet from doing a bunch of magic
    catalog.add_resource resource
    catalog.apply
  end

  [:defined, :present].each do |ensure_setting|
    describe "When setting ensure => #{ensure_setting}" do
      it "should create an fstab entry if none exists" do
        @mounted = false
        @umount_permitted = false
        run_in_catalog(ensure_setting)
        @mounted.should == false
        check_fstab
      end
    end
  end

  it "should be able to create and mount a brand new mount point" do
    @mounted = false
    @umount_permitted = true # Work around bug #6632
    run_in_catalog(:mounted)
    @mounted.should == true
    check_fstab
  end

  it "should be able to create an fstab entry for an already-mounted device" do
    @mounted = true
    @umount_permitted = true # Work around bug #6633
    run_in_catalog(:mounted)
    @mounted.should == true
    check_fstab
  end
end
