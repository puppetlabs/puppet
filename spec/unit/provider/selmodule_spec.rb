# Note: This unit test depends on having a sample SELinux policy file
# in the same directory as this test called selmodule-example.pp
# with version 1.5.0.  The provided selmodule-example.pp is the first
# 256 bytes taken from /usr/share/selinux/targeted/nagios.pp on Fedora 9

require 'spec_helper'
require 'stringio'

provider_class = Puppet::Type.type(:selmodule).provider(:semodule)

describe provider_class do
  before :each do
    @resource = double("resource", :name => "foo")
    allow(@resource).to receive(:[]).and_return("foo")
    @provider = provider_class.new(@resource)
  end

  describe "exists? method" do
    it "should find a module if it is already loaded" do
      expect(@provider).to receive(:command).with(:semodule).and_return("/usr/sbin/semodule")
      expect(@provider).to receive(:execpipe).with("/usr/sbin/semodule --list").and_yield(StringIO.new("bar\t1.2.3\nfoo\t4.4.4\nbang\t1.0.0\n"))
      expect(@provider.exists?).to eq(:true)
    end

    it "should return nil if not loaded" do
      expect(@provider).to receive(:command).with(:semodule).and_return("/usr/sbin/semodule")
      expect(@provider).to receive(:execpipe).with("/usr/sbin/semodule --list").and_yield(StringIO.new("bar\t1.2.3\nbang\t1.0.0\n"))
      expect(@provider.exists?).to be_nil
    end

    it "should return nil if module with same suffix is loaded" do
      expect(@provider).to receive(:command).with(:semodule).and_return("/usr/sbin/semodule")
      expect(@provider).to receive(:execpipe).with("/usr/sbin/semodule --list").and_yield(StringIO.new("bar\t1.2.3\nmyfoo\t1.0.0\n"))
      expect(@provider.exists?).to be_nil
    end

    it "should return nil if no modules are loaded" do
      expect(@provider).to receive(:command).with(:semodule).and_return("/usr/sbin/semodule")
      expect(@provider).to receive(:execpipe).with("/usr/sbin/semodule --list").and_yield(StringIO.new(""))
      expect(@provider.exists?).to be_nil
    end
  end

  describe "selmodversion_file" do
    it "should return 1.5.0 for the example policy file" do
      expect(@provider).to receive(:selmod_name_to_filename).and_return("#{File.dirname(__FILE__)}/selmodule-example.pp")
      expect(@provider.selmodversion_file).to eq("1.5.0")
    end
  end

  describe "syncversion" do
    it "should return :true if loaded and file modules are in sync" do
      expect(@provider).to receive(:selmodversion_loaded).and_return("1.5.0")
      expect(@provider).to receive(:selmodversion_file).and_return("1.5.0")
      expect(@provider.syncversion).to eq(:true)
    end

    it "should return :false if loaded and file modules are not in sync" do
      expect(@provider).to receive(:selmodversion_loaded).and_return("1.4.0")
      expect(@provider).to receive(:selmodversion_file).and_return("1.5.0")
      expect(@provider.syncversion).to eq(:false)
    end

    it "should return before checking file version if no loaded policy" do
      expect(@provider).to receive(:selmodversion_loaded).and_return(nil)
      expect(@provider.syncversion).to eq(:false)
    end
  end

  describe "selmodversion_loaded" do
    it "should return the version of a loaded module" do
      expect(@provider).to receive(:command).with(:semodule).and_return("/usr/sbin/semodule")
      expect(@provider).to receive(:execpipe).with("/usr/sbin/semodule --list").and_yield(StringIO.new("bar\t1.2.3\nfoo\t4.4.4\nbang\t1.0.0\n"))
      expect(@provider.selmodversion_loaded).to eq("4.4.4")
    end

    it 'should return raise an exception when running selmodule raises an exception' do
      expect(@provider).to receive(:command).with(:semodule).and_return("/usr/sbin/semodule")
      expect(@provider).to receive(:execpipe).with("/usr/sbin/semodule --list").and_yield("this is\nan error").and_raise(Puppet::ExecutionFailure, 'it failed')
      expect {@provider.selmodversion_loaded}.to raise_error(Puppet::ExecutionFailure, /Could not list policy modules: ".*" failed with "this is an error"/)
    end
  end
end
