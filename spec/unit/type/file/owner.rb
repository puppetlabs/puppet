#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

property = Puppet::Type.type(:file).attrclass(:owner)

describe property do
    before do
        @resource = stub 'resource', :line => "foo", :file => "bar"
        @resource.stubs(:[]).returns "foo"
        @resource.stubs(:[]).with(:path).returns "/my/file"
        @owner = property.new :resource => @resource
    end

    it "should have a method for testing whether an owner is valid" do
        @owner.must respond_to(:validuser?)
    end

    it "should return the found uid if an owner is valid" do
        @owner.expects(:uid).with("foo").returns 500
        @owner.validuser?("foo").should == 500
    end

    it "should return false if an owner is not valid" do
        @owner.expects(:uid).with("foo").returns nil
        @owner.validuser?("foo").should be_false
    end

    describe "when retrieving the current value" do
        it "should return :absent if the file cannot stat" do
            @resource.expects(:stat).returns nil

            @owner.retrieve.should == :absent
        end

        it "should get the uid from the stat instance from the file" do
            stat = stub 'stat', :ftype => "foo"
            @resource.expects(:stat).returns stat
            stat.expects(:uid).returns 500

            @owner.retrieve.should == 500
        end

        it "should warn and return :silly if the found value is higher than the maximum uid value" do
            Puppet.settings.expects(:value).with(:maximum_uid).returns 500

            stat = stub 'stat', :ftype => "foo"
            @resource.expects(:stat).returns stat
            stat.expects(:uid).returns 1000

            @owner.expects(:warning)
            @owner.retrieve.should == :silly
        end
    end

    describe "when determining if the file is in sync" do
        describe "and not running as root" do
            it "should warn once and return true" do
                Puppet::Util::SUIDManager.expects(:uid).returns 1

                @owner.expects(:warnonce)

                @owner.should = [10]
                @owner.must be_insync(20)
            end
        end

        before do
            Puppet::Util::SUIDManager.stubs(:uid).returns 0
        end

        it "should be in sync if 'should' is not provided" do
            @owner.must be_insync(10)
        end

        it "should directly compare the owner values if the desired owner is an integer" do
            @owner.should = [10]
            @owner.must be_insync(10)
        end

        it "should treat numeric strings as integers" do
            @owner.should = ["10"]
            @owner.must be_insync(10)
        end

        it "should convert the owner name to an integer if the desired owner is a string" do
            @owner.expects(:uid).with("foo").returns 10
            @owner.should = %w{foo}

            @owner.must be_insync(10)
        end
        
        it "should not validate that users exist when a user is specified as an integer" do
            @owner.expects(:uid).never
            @owner.validuser?(10)
        end

        it "should fail if it cannot convert an owner name to an integer" do
            @owner.expects(:uid).with("foo").returns nil
            @owner.should = %w{foo}

            lambda { @owner.insync?(10) }.should raise_error(Puppet::Error)
        end

        it "should return false if the owners are not equal" do
            @owner.should = [10]
            @owner.should_not be_insync(20)
        end
    end

    describe "when changing the owner" do
        before do
            @owner.should = %w{one}
            @owner.stubs(:path).returns "path"
            @owner.stubs(:uid).returns 500
        end

        it "should chown the file if :links is set to :follow" do
            @resource.expects(:[]).with(:links).returns :follow
            File.expects(:chown)

            @owner.sync
        end

        it "should lchown the file if :links is set to :manage" do
            @resource.expects(:[]).with(:links).returns :manage
            File.expects(:lchown)

            @owner.sync
        end

        it "should use the first valid owner in its 'should' list" do
            @owner.should = %w{one two three}
            @owner.expects(:validuser?).with("one").returns nil
            @owner.expects(:validuser?).with("two").returns 500
            @owner.expects(:validuser?).with("three").never

            File.expects(:chown).with(500, nil, "/my/file")

            @owner.sync
        end
    end
end
