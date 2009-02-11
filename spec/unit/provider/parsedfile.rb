#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/provider/parsedfile'

# Most of the tests for this are still in test/ral/provider/parsedfile.rb.
describe Puppet::Provider::ParsedFile do
    before do
        @class = Class.new(Puppet::Provider::ParsedFile)
    end

    describe "when looking up records loaded from disk" do
        it "should return nil if no records have been loaded" do
            @class.record?("foo").should be_nil
        end
    end

    describe "when generating a list of instances" do
        it "should return an instance for each record parsed from all of the registered targets" do
            @class.expects(:targets).returns %w{/one /two}
            @class.stubs(:skip_record?).returns false
            one = [:uno1, :uno2]
            two = [:dos1, :dos2]
            @class.expects(:prefetch_target).with("/one").returns one
            @class.expects(:prefetch_target).with("/two").returns two

            results = []
            (one + two).each do |inst|
                results << inst.to_s + "_instance"
                @class.expects(:new).with(inst).returns(results[-1])
            end

            @class.instances.should == results
        end

        it "should skip specified records" do
            @class.expects(:targets).returns %w{/one}
            @class.expects(:skip_record?).with(:uno).returns false
            @class.expects(:skip_record?).with(:dos).returns true
            one = [:uno, :dos]
            @class.expects(:prefetch_target).returns one

            @class.expects(:new).with(:uno).returns "eh"
            @class.expects(:new).with(:dos).never

            @class.instances
        end
    end
end
