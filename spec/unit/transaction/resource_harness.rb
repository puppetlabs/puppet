#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/transaction/resource_harness'

describe Puppet::Transaction::ResourceHarness do
    before do
        @transaction = Puppet::Transaction.new(Puppet::Resource::Catalog.new)
        @resource = Puppet::Type.type(:file).new :path => "/my/file"
        @harness = Puppet::Transaction::ResourceHarness.new(@transaction)
        @current_state = Puppet::Resource.new(:file, "/my/file")
        @resource.stubs(:retrieve).returns @current_state
        @status = Puppet::Resource::Status.new(@resource)
        Puppet::Resource::Status.stubs(:new).returns @status
    end

    it "should accept a transaction at initialization" do
        harness = Puppet::Transaction::ResourceHarness.new(@transaction)
        harness.transaction.should equal(@transaction)
    end

    it "should delegate to the transaction for its relationship graph" do
        @transaction.expects(:relationship_graph).returns "relgraph"
        Puppet::Transaction::ResourceHarness.new(@transaction).relationship_graph.should == "relgraph"
    end

    describe "when evaluating a resource" do
        it "should create and return a resource status instance for the resource" do
            @harness.evaluate(@resource).should be_instance_of(Puppet::Resource::Status)
        end

        it "should fail if no status can be created" do
            Puppet::Resource::Status.expects(:new).raises ArgumentError

            lambda { @harness.evaluate(@resource) }.should raise_error
        end

        it "should retrieve the current state of the resource" do
            @resource.expects(:retrieve).returns @current_state
            @harness.evaluate(@resource)
        end

        it "should mark the resource as failed and return if the current state cannot be retrieved" do
            @resource.expects(:retrieve).raises ArgumentError
            @harness.evaluate(@resource).should be_failed
        end

        it "should use the status and retrieved state to determine which changes need to be made" do
            @harness.expects(:changes_to_perform).with(@status, @resource).returns []
            @harness.evaluate(@resource)
        end

        it "should mark the status as out of sync and apply the created changes if there are any" do
            changes = %w{mychanges}
            @harness.expects(:changes_to_perform).returns changes
            @harness.expects(:apply_changes).with(@status, changes)
            @harness.evaluate(@resource).should be_out_of_sync
        end

        it "should cache the last-synced time" do
            changes = %w{mychanges}
            @harness.stubs(:changes_to_perform).returns changes
            @harness.stubs(:apply_changes)
            @resource.expects(:cache).with { |name, time| name == :synced and time.is_a?(Time) }
            @harness.evaluate(@resource)
        end

        it "should flush the resource when applying changes if appropriate" do
            changes = %w{mychanges}
            @harness.stubs(:changes_to_perform).returns changes
            @harness.stubs(:apply_changes)
            @resource.expects(:flush)
            @harness.evaluate(@resource)
        end

        it "should use the status and retrieved state to determine which changes need to be made" do
            @harness.expects(:changes_to_perform).with(@status, @resource).returns []
            @harness.evaluate(@resource)
        end

        it "should not attempt to apply changes if none need to be made" do
            @harness.expects(:changes_to_perform).returns []
            @harness.expects(:apply_changes).never
            @harness.evaluate(@resource).should_not be_out_of_sync
        end

        it "should store the resource's evaluation time in the resource status" do
            @harness.evaluate(@resource).evaluation_time.should be_instance_of(Float)
        end

        it "should set the change count to the total number of changes" do
            changes = %w{a b c d}
            @harness.expects(:changes_to_perform).returns changes
            @harness.expects(:apply_changes).with(@status, changes)
            @harness.evaluate(@resource).change_count.should == 4
        end
    end

    describe "when creating changes" do
        before do
            @current_state = Puppet::Resource.new(:file, "/my/file")
            @resource.stubs(:retrieve).returns @current_state
            Puppet::Util::SUIDManager.stubs(:uid).returns 0
        end

        it "should retrieve the current values from the resource" do
            @resource.expects(:retrieve).returns @current_state
            @harness.changes_to_perform(@status, @resource)
        end

        it "should cache that the resource was checked" do
            @resource.expects(:cache).with { |name, time| name == :checked and time.is_a?(Time) }
            @harness.changes_to_perform(@status, @resource)
        end

        it "should create changes with the appropriate property and current value" do
            @resource[:ensure] = :present
            @current_state[:ensure] = :absent

            change = stub 'change'
            Puppet::Transaction::Change.expects(:new).with(@resource.parameter(:ensure), :absent).returns change

            @harness.changes_to_perform(@status, @resource)[0].should equal(change)
        end

        it "should not attempt to manage properties that do not have desired values set" do
            mode = @resource.newattr(:mode)
            @current_state[:mode] = :absent

            mode.expects(:insync?).never

            @harness.changes_to_perform(@status, @resource)
        end

        describe "and the 'ensure' parameter is present but not in sync" do
            it "should return a single change for the 'ensure' parameter" do
                @resource[:ensure] = :present
                @resource[:mode] = "755"
                @current_state[:ensure] = :absent
                @current_state[:mode] = :absent

                @resource.stubs(:retrieve).returns @current_state

                changes = @harness.changes_to_perform(@status, @resource)
                changes.length.should == 1
                changes[0].property.name.should == :ensure
            end
        end

        describe "and the 'ensure' parameter should be set to 'absent', and is correctly set to 'absent'" do
            it "should return no changes" do
                @resource[:ensure] = :absent
                @resource[:mode] = "755"
                @current_state[:ensure] = :absent
                @current_state[:mode] = :absent

                @harness.changes_to_perform(@status, @resource).should == []
            end
        end

        describe "and the 'ensure' parameter is 'absent' and there is no 'desired value'" do
            it "should return no changes" do
                @resource.newattr(:ensure)
                @resource[:mode] = "755"
                @current_state[:ensure] = :absent
                @current_state[:mode] = :absent

                @harness.changes_to_perform(@status, @resource).should == []
            end
        end

        describe "and non-'ensure' parameters are not in sync" do
            it "should return a change for each parameter that is not in sync" do
                @resource[:ensure] = :present
                @resource[:mode] = "755"
                @resource[:owner] = 0
                @current_state[:ensure] = :present
                @current_state[:mode] = 0444
                @current_state[:owner] = 50

                mode = stub 'mode_change'
                owner = stub 'owner_change'
                Puppet::Transaction::Change.expects(:new).with(@resource.parameter(:mode), 0444).returns mode
                Puppet::Transaction::Change.expects(:new).with(@resource.parameter(:owner), 50).returns owner

                changes = @harness.changes_to_perform(@status, @resource)
                changes.length.should == 2
                changes.should be_include(mode)
                changes.should be_include(owner)
            end
        end

        describe "and all parameters are in sync" do
            it "should return an empty array" do
                @resource[:ensure] = :present
                @resource[:mode] = "755"
                @current_state[:ensure] = :present
                @current_state[:mode] = 0755
                @harness.changes_to_perform(@status, @resource).should == []
            end
        end
    end

    describe "when applying changes" do
        before do
            @change1 = stub 'change1', :apply => stub("event", :status => "success")
            @change2 = stub 'change2', :apply => stub("event", :status => "success")
            @changes = [@change1, @change2]
        end

        it "should apply the change" do
            @change1.expects(:apply).returns( stub("event", :status => "success") )
            @change2.expects(:apply).returns( stub("event", :status => "success") )

            @harness.apply_changes(@status, @changes)
        end

        it "should mark the resource as changed" do
            @harness.apply_changes(@status, @changes)

            @status.should be_changed
        end

        it "should queue the resulting event" do
            @harness.apply_changes(@status, @changes)

            @status.events.should be_include(@change1.apply)
            @status.events.should be_include(@change2.apply)
        end
    end

    describe "when determining whether the resource can be changed" do
        before do
            @resource.stubs(:purging?).returns true
            @resource.stubs(:deleting?).returns true
        end

        it "should be true if the resource is not being purged" do
            @resource.expects(:purging?).returns false
            @harness.should be_allow_changes(@resource)
        end

        it "should be true if the resource is not being deleted" do
            @resource.expects(:deleting?).returns false
            @harness.should be_allow_changes(@resource)
        end

        it "should be true if the resource has no dependents" do
            @harness.relationship_graph.expects(:dependents).with(@resource).returns []
            @harness.should be_allow_changes(@resource)
        end

        it "should be true if all dependents are being deleted" do
            dep = stub 'dependent', :deleting? => true
            @harness.relationship_graph.expects(:dependents).with(@resource).returns [dep]
            @resource.expects(:purging?).returns true
            @harness.should be_allow_changes(@resource)
        end

        it "should be false if the resource's dependents are not being deleted" do
            dep = stub 'dependent', :deleting? => false, :ref => "myres"
            @resource.expects(:warning)
            @harness.relationship_graph.expects(:dependents).with(@resource).returns [dep]
            @harness.should_not be_allow_changes(@resource)
        end
    end
end
