#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

property = Puppet::Type.type(:file).attrclass(:content)

describe property do
    before do
        @resource = stub 'resource', :line => "foo", :file => "bar", :replace? => true
        @resource.stubs(:[]).returns "foo"
        @resource.stubs(:[]).with(:path).returns "/my/file"
        @content = property.new :resource => @resource
    end

    it "should not include current contents when producing a change log" do
        @content.change_to_s("current_content", "desired").should_not be_include("current_content")
    end

    it "should not include desired contents when producing a change log" do
        @content.change_to_s("current", "desired_content").should_not be_include("desired_content")
    end

    it "should not include the content when converting current content to a string" do
        @content.is_to_s("my_content").should_not be_include("my_content")
    end

    it "should not include the content when converting desired content to a string" do
        @content.should_to_s("my_content").should_not be_include("my_content")
    end
end
