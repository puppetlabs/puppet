#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

zone = Puppet::Type.type(:zone)

describe zone do
    before do
	zone = Puppet::Type.type(:zone)
        provider = stub 'provider'
	provider.stubs(:name).returns(:solaris)
	zone.stubs(:defaultprovider).returns(provider)
        resource = stub 'resource', :resource => nil, :provider => provider, :line => nil, :file => nil
    end

    parameters = [:create_args, :install_args, :sysidcfg, :path, :realhostname]

    parameters.each do |parameter|
        it "should have a %s parameter" % parameter do
            zone.attrclass(parameter).ancestors.should be_include(Puppet::Parameter)
        end
    end

    properties = [:ip, :iptype, :autoboot, :pool, :shares, :inherit]

    properties.each do |property|
        it "should have a %s property" % property do
            zone.attrclass(property).ancestors.should be_include(Puppet::Property)
        end
    end

    it "should be invalid when :path is missing" do
        lambda { zone.new(:name => "dummy") }.should raise_error
    end

    it "should be invalid when :ip is missing a \":\" and iptype is :shared" do
        lambda { zone.new(:name => "dummy", :ip => "if") }.should raise_error
    end

    it "should be invalid when :ip has a \":\" and iptype is :exclusive" do
        lambda { zone.new(:name => "dummy", :ip => "if:1.2.3.4",
	    :iptype => :exclusive) }.should raise_error
    end

    it "should be invalid when :ip has two \":\" and iptype is :exclusive" do
        lambda { zone.new(:name => "dummy", :ip => "if:1.2.3.4:2.3.4.5",
	    :iptype => :exclusive) }.should raise_error
    end

    it "should be valid when :iptype is :shared and using interface and ip" do
        zone.new(:name => "dummy", :path => "/dummy", :ip => "if:1.2.3.4")
    end

    it "should be valid when :iptype is :shared and using interface, ip and default route" do
        zone.new(:name => "dummy", :path => "/dummy", :ip => "if:1.2.3.4:2.3.4.5")
    end

    it "should be valid when :iptype is :exclusive and using interface" do
        zone.new(:name => "dummy", :path => "/dummy", :ip => "if",
	    :iptype => :exclusive)
    end

end
