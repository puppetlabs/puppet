#!/usr/bin/env ruby

# Find and load the spec file.
Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

provider = Puppet::Type.type(:service).provider(:init)

describe provider do
  describe "when running on FreeBSD", :if => (Facter.value(:operatingsystem) == "FreeBSD") do
    it "should set its default path to include /etc/init.d and /usr/local/etc/init.d" do
      provider.defpath.should == ["/etc/rc.d", "/usr/local/etc/rc.d"]
    end
  end

  describe "when running on HP-UX", :if => (Facter.value(:operatingsystem) == "HP-UX")do
    it "should set its default path to include /sbin/init.d" do
      provider.defpath.should == "/sbin/init.d"
    end
  end

  describe "when not running on FreeBSD or HP-UX", :if => (! %w{HP-UX FreeBSD}.include?(Facter.value(:operatingsystem))) do
    it "should set its default path to include /etc/init.d" do
      provider.defpath.should == "/etc/init.d"
    end
  end
end
