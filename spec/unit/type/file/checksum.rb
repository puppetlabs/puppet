#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

checksum = Puppet::Type.type(:file).attrclass(:checksum)
describe checksum do
    before do
        # Wow that's a messy interface to the resource.
        @resource = stub 'resource', :[] => nil, :[]= => nil, :property => nil, :newattr => nil, :parameter => nil
    end

    it "should be a subclass of Property" do
        checksum.superclass.must == Puppet::Property
    end

    it "should have default checksum of :md5" do
        @checksum = checksum.new(:resource => @resource)
        @checksum.checktype.should == :md5
    end

    [:none, nil, ""].each do |ck|
        it "should use a none checksum for #{ck.inspect}" do
            @checksum = checksum.new(:resource => @resource)
            @checksum.should = "none"
            @checksum.checktype.should == :none
        end
    end
end
