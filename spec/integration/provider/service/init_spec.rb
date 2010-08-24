#!/usr/bin/env ruby

# Find and load the spec file.
Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

provider = Puppet::Type.type(:service).provider(:init)

describe provider do
  describe "when running on FreeBSD" do
    confine "Not running on FreeBSD" => (Facter.value(:operatingsystem) == "FreeBSD")

    it "should set its default path to include /etc/init.d and /usr/local/etc/init.d" do
      provider.defpath.should == ["/etc/rc.d", "/usr/local/etc/rc.d"]
    end
  end

  describe "when running on HP-UX" do
    confine "Not running on HP-UX" => (Facter.value(:operatingsystem) == "HP-UX")

    it "should set its default path to include /sbin/init.d" do
      provider.defpath.should == "/sbin/init.d"
    end
  end

  describe "when not running on FreeBSD or HP-UX" do
    confine "Running on HP-UX or FreeBSD" => (! %w{HP-UX FreeBSD}.include?(Facter.value(:operatingsystem)))

    it "should set its default path to include /etc/init.d" do
      provider.defpath.should == "/etc/init.d"
    end
  end
end
