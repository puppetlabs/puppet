#!/usr/bin/env rspec
require 'spec_helper'

property = Puppet::Type.type(:file).attrclass(:mode)

describe property do
  before do
    @resource = stub 'resource', :line => "foo", :file => "bar"
    @resource.stubs(:[]).returns "foo"
    @resource.stubs(:[]).with(:path).returns "/my/file"
    @mode = property.new :resource => @resource
  end

  describe "when changing the mode" do
    before do
    end

    it "should handle 3 to 3 digit file mode" do
      @mode.stubs(:mode).returns 644
      @mode.should = '755'
      File.expects(:chmod).with('755'.to_i(8), "/my/file")

      @mode.sync
      # for some reasons it's not logging yet.
      #@logs.first.message.should =~ /0644/
    end

    it "should handle 3 to 4 digit file mode" do
      @mode.stubs(:mode).returns 644
      @mode.should = '1755'
      File.expects(:chmod).with('1755'.to_i(8), "/my/file")

      @mode.sync
    end

    it "should handle 4 to 3 digit file mode" do
      @mode.stubs(:mode).returns 1755
      @mode.should = '644'
      File.expects(:chmod).with('644'.to_i(8), "/my/file")

      @mode.sync
    end

    it "should handle 4 to 4 digit file mode" do
      @mode.stubs(:mode).returns 1755
      @mode.should = '1644'
      File.expects(:chmod).with('1644'.to_i(8), "/my/file")

      @mode.sync
    end
  end
end
