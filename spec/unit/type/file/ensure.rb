#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

property = Puppet::Type.type(:file).attrclass(:ensure)

describe property do
    before do
        @resource = stub 'resource', :line => "foo", :file => "bar", :replace? => true
        @resource.stubs(:[]).returns "foo"
        @resource.stubs(:[]).with(:path).returns "/my/file"
        @ensure = property.new :resource => @resource
    end

    describe "when testing whether in sync" do
        it "should always be in sync if replace is 'false' unless the file is missing" do
            @resource.expects(:replace?).returns false
            @ensure.insync?(:link).should be_true
        end
    end
end
