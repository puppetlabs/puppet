#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

property = Puppet::Type.type(:file).attrclass(:group)

describe property do
    before do
        @resource = mock 'resource'
        @resource.stubs(:[]).returns "foo"
        @resource.stubs(:[]).with(:path).returns "/my/file"
        @group = property.new :resource => @resource
    end

    it "should have a method for testing whether a group is valid" do
        @group.must respond_to(:validgroup?)
    end

    it "should return the found gid if a group is valid" do
        @group.expects(:gid).with("foo").returns 500
        @group.validgroup?("foo").should == 500
    end

    it "should return false if a group is not valid" do
        @group.expects(:gid).with("foo").returns nil
        @group.validgroup?("foo").should be_false
    end

    describe "when retrieving the current value" do
        it "should return :absent if the file cannot stat" do
            @resource.expects(:stat).returns nil

            @group.retrieve.should == :absent
        end

        it "should get the gid from the stat instance from the file" do
            stat = stub 'stat', :ftype => "foo"
            @resource.expects(:stat).returns stat
            stat.expects(:gid).returns 500

            @group.retrieve.should == 500
        end

        it "should warn and return :silly if the found value is higher than the maximum uid value" do
            Puppet.settings.expects(:value).with(:maximum_uid).returns 500

            stat = stub 'stat', :ftype => "foo"
            @resource.expects(:stat).returns stat
            stat.expects(:gid).returns 1000

            @group.expects(:warning)
            @group.retrieve.should == :silly
        end
    end

    describe "when changing the group" do
        before do
            @group.should = %w{one}
            @group.stubs(:gid).returns 500
        end

        it "should chown the file if :links is set to :follow" do
            @resource.expects(:[]).with(:links).returns :follow
            File.expects(:chown)

            @group.sync
        end

        it "should lchown the file if :links is set to :manage" do
            @resource.expects(:[]).with(:links).returns :manage
            File.expects(:lchown)

            @group.sync
        end

        it "should use the first valid group in its 'should' list" do
            @group.should = %w{one two three}
            @group.expects(:validgroup?).with("one").returns nil
            @group.expects(:validgroup?).with("two").returns 500
            @group.expects(:validgroup?).with("three").never

            File.expects(:chown).with(nil, 500, "/my/file")

            @group.sync
        end
    end
end
