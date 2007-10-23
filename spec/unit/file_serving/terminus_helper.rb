#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-22.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/file_serving/terminus_helper'

describe Puppet::FileServing::TerminusHelper do
    before do
        @helper = Object.new
        @helper.extend(Puppet::FileServing::TerminusHelper)

        @model = mock 'model'
        @helper.stubs(:model).returns(@model)
    end

    it "should use a fileset to find paths" do
        fileset = mock 'fileset', :files => []
        Puppet::FileServing::Fileset.expects(:new).with("/my/file", {}).returns(fileset)
        @helper.path2instances("/my/file")
    end

    it "should pass :recurse, :ignore, and :links settings on to the fileset if present" do
        fileset = mock 'fileset', :files => []
        Puppet::FileServing::Fileset.expects(:new).with("/my/file", :links => :a, :ignore => :b, :recurse => :c).returns(fileset)
        @helper.path2instances("/my/file", :links => :a, :ignore => :b, :recurse => :c)
    end

    it "should return an instance of the model for each path returned by the fileset" do
        fileset = mock 'fileset', :files => %w{one two}
        Puppet::FileServing::Fileset.expects(:new).with("/my/file", {}).returns(fileset)
        @model.expects(:new).with("one").returns(:one)
        @model.expects(:new).with("two").returns(:two)
        @helper.path2instances("/my/file").should == [:one, :two]
    end
end
