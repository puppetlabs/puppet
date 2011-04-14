#!/usr/bin/env rspec

# Note: This unit test depends on having a sample SELinux policy file
# in the same directory as this test called selmodule-example.pp
# with version 1.5.0.  The provided selmodule-example.pp is the first
# 256 bytes taken from /usr/share/selinux/targeted/nagios.pp on Fedora 9

require 'spec_helper'

provider_class = Puppet::Type.type(:selmodule).provider(:semodule)

describe provider_class do
  before :each do
    @resource = stub("resource", :name => "foo")
    @resource.stubs(:[]).returns "foo"
    @provider = provider_class.new(@resource)
  end

  describe "exists? method" do
    it "should find a module if it is already loaded" do
      @provider.expects(:command).with(:semodule).returns "/usr/sbin/semodule"
      @provider.expects(:execpipe).with("/usr/sbin/semodule --list").yields ["bar\t1.2.3\n", "foo\t4.4.4\n", "bang\t1.0.0\n"]
      @provider.exists?.should == :true
    end

    it "should return nil if not loaded" do
      @provider.expects(:command).with(:semodule).returns "/usr/sbin/semodule"
      @provider.expects(:execpipe).with("/usr/sbin/semodule --list").yields ["bar\t1.2.3\n", "bang\t1.0.0\n"]
      @provider.exists?.should be_nil
    end

    it "should return nil if no modules are loaded" do
      @provider.expects(:command).with(:semodule).returns "/usr/sbin/semodule"
      @provider.expects(:execpipe).with("/usr/sbin/semodule --list").yields []
      @provider.exists?.should be_nil
    end
  end

  describe "selmodversion_file" do
    it "should return 1.5.0 for the example policy file" do
      @provider.expects(:selmod_name_to_filename).returns "#{File.dirname(__FILE__)}/selmodule-example.pp"
      @provider.selmodversion_file.should == "1.5.0"
    end
  end

  describe "syncversion" do
    it "should return :true if loaded and file modules are in sync" do
      @provider.expects(:selmodversion_loaded).returns "1.5.0"
      @provider.expects(:selmodversion_file).returns "1.5.0"
      @provider.syncversion.should == :true
    end

    it "should return :false if loaded and file modules are not in sync" do
      @provider.expects(:selmodversion_loaded).returns "1.4.0"
      @provider.expects(:selmodversion_file).returns "1.5.0"
      @provider.syncversion.should == :false
    end

    it "should return before checking file version if no loaded policy" do
      @provider.expects(:selmodversion_loaded).returns nil
      @provider.syncversion.should == :false
    end

  end

end
