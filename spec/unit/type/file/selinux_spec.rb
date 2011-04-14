#!/usr/bin/env rspec
require 'spec_helper'


[:seluser, :selrole, :seltype, :selrange].each do |param|
  property = Puppet::Type.type(:file).attrclass(param)
  describe property do
    before do
      @resource = Puppet::Type.type(:file).new :path => "/my/file"
      @sel = property.new :resource => @resource
    end

    it "retrieve on #{param} should return :absent if the file isn't statable" do
      @resource.expects(:stat).returns nil
      @sel.retrieve.should == :absent
    end

    it "should retrieve nil for #{param} if there is no SELinux support" do
      stat = stub 'stat', :ftype => "foo"
      @resource.expects(:stat).returns stat
      @sel.expects(:get_selinux_current_context).with("/my/file").returns nil
      @sel.retrieve.should be_nil
    end

    it "should retrieve #{param} if a SELinux context is found with a range" do
      stat = stub 'stat', :ftype => "foo"
      @resource.expects(:stat).returns stat
      @sel.expects(:get_selinux_current_context).with("/my/file").returns "user_u:role_r:type_t:s0"
      expectedresult = case param
        when :seluser; "user_u"
        when :selrole; "role_r"
        when :seltype; "type_t"
        when :selrange; "s0"
      end
      @sel.retrieve.should == expectedresult
    end

    it "should retrieve #{param} if a SELinux context is found without a range" do
      stat = stub 'stat', :ftype => "foo"
      @resource.expects(:stat).returns stat
      @sel.expects(:get_selinux_current_context).with("/my/file").returns "user_u:role_r:type_t"
      expectedresult = case param
        when :seluser; "user_u"
        when :selrole; "role_r"
        when :seltype; "type_t"
        when :selrange; nil
      end
      @sel.retrieve.should == expectedresult
    end

    it "should handle no default gracefully" do
      @sel.expects(:get_selinux_default_context).with("/my/file").returns nil
      @sel.default.must be_nil
    end

    it "should be able to detect matchpathcon defaults" do
      @sel.stubs(:debug)
      @sel.expects(:get_selinux_default_context).with("/my/file").returns "user_u:role_r:type_t:s0"
      expectedresult = case param
        when :seluser; "user_u"
        when :selrole; "role_r"
        when :seltype; "type_t"
        when :selrange; "s0"
      end
      @sel.default.must == expectedresult
    end

    it "should return nil for defaults if selinux_ignore_defaults is true" do
      @resource[:selinux_ignore_defaults] = :true
      @sel.default.must be_nil
    end

    it "should be able to set a new context" do
      stat = stub 'stat', :ftype => "foo"
      @sel.should = %w{newone}
      @sel.expects(:set_selinux_context).with("/my/file", ["newone"], param)
      @sel.sync
    end

    it "should do nothing for safe_insync? if no SELinux support" do
      @sel.should = %{newcontext}
      @sel.expects(:selinux_support?).returns false
      @sel.safe_insync?("oldcontext").should == true
    end
  end
end

