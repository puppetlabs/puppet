#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-9-12.
#  Copyright (c) 2006. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet_spec/files'
require 'puppettest/support/utils'
require 'puppettest/fileparsing'

module ParsedMountTesting
  include PuppetTest::Support::Utils
  include PuppetTest::FileParsing
  include PuppetSpec::Files

  def fake_fstab
    os = Facter.value(:operatingsystem)
    if os == "Solaris"
      name = "solaris.fstab"
    elsif os == "FreeBSD"
      name = "freebsd.fstab"
    else
      # Catchall for other fstabs
      name = "linux.fstab"
    end
    fakefile(File::join("data/types/mount", name))
  end


end

provider_class = Puppet::Type.type(:mount).provider(:parsed)

describe provider_class do
  before :each do
    @mount_class = Puppet::Type.type(:mount)
    @provider_class = @mount_class.provider(:parsed)
  end


  describe provider_class do
    include ParsedMountTesting

    it "should be able to parse all of the example mount tabs" do
      tab = fake_fstab
      @provider = @provider_class

      # LAK:FIXME Again, a relatively bad test, but I don't know how to rspec-ify this.
      # I suppose this is more of an integration test?  I dunno.
      fakedataparse(tab) do
        # Now just make we've got some mounts we know will be there
        hashes = @provider_class.target_records(tab).find_all { |i| i.is_a? Hash }
        (hashes.length > 0).should be_true
        root = hashes.find { |i| i[:name] == "/" }

        proc { @provider_class.to_file(hashes) }.should_not raise_error
      end
    end

    # LAK:FIXME I can't mock Facter because this test happens at parse-time.
    it "should default to /etc/vfstab on Solaris and /etc/fstab everywhere else" do
      should = case Facter.value(:operatingsystem)
        when "Solaris"; "/etc/vfstab"
        else
          "/etc/fstab"
        end
      Puppet::Type.type(:mount).provider(:parsed).default_target.should == should
    end

    it "should not crash on incomplete lines in fstab" do
      parse = @provider_class.parse <<-FSTAB
/dev/incomplete
/dev/device       name
      FSTAB

      lambda{ @provider_class.to_line(parse[0]) }.should_not raise_error
    end
  end



  describe provider_class, " when parsing information about the root filesystem", :if => Facter["operatingsystem"].value != "Darwin" do
    include ParsedMountTesting

    before do
      @mount = @mount_class.new :name => "/"
      @provider = @mount.provider
    end

    it "should have a filesystem tab" do
      FileTest.should be_exist(@provider_class.default_target)
    end

    it "should find the root filesystem" do
      @provider_class.prefetch("/" => @mount)
      @mount.provider.property_hash[:ensure].should == :present
    end

    it "should determine that the root fs is mounted" do
      @provider_class.prefetch("/" => @mount)
      @mount.provider.should be_mounted
    end
  end

  describe provider_class, " when mounting and unmounting" do
    include ParsedMountTesting

    it "should call the 'mount' command to mount the filesystem"

    it "should call the 'unmount' command to unmount the filesystem"

    it "should specify the filesystem when remounting a filesystem"
  end
end
