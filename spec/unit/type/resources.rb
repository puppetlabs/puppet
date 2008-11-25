#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

resources = Puppet::Type.type(:resources)

# There are still plenty of tests to port over from test/.
describe resources do
    describe "when initializing" do
        before do
            resources.clear
        end

        it "should fail if the specified resource type does not exist" do
            Puppet::Type.expects(:type).with("nosuchtype").returns nil
            lambda { resources.create :name => "nosuchtype" }.should raise_error(Puppet::Error)
        end

        it "should not fail when the specified resource type exists" do
            lambda { resources.create :name => "file" }.should_not raise_error
        end

        it "should set its :resource_type attribute" do
            resources.create(:name => "file").resource_type.should == Puppet::Type.type(:file)
        end
    end
end
