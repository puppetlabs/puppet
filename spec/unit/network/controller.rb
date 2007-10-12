#!/usr/bin/env ruby
#
#  Created by Rick Bradley on 2007-10-03.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/network/controller'

describe Puppet::Network::Controller, "when initializing" do
    it "should require an indirection name" do
        Proc.new { Puppet::Network::Controller.new }.should raise_error(ArgumentError)
    end
end

describe Puppet::Network::Controller, "after initialization" do
    before do
        @mock_model_class = mock('model class')
        Puppet::Network::Controller.any_instance.stubs(:model_class_from_indirection_name).returns(@mock_model_class)
        @controller = Puppet::Network::Controller.new(:indirection => :foo)
    end

    it "should delegate find to the indirection's model class's find" do
        @mock_model_class.expects(:find).returns({:foo => :bar})
        @controller.find.should == { :foo => :bar }
    end
    
    it "should delegate search to the indirection's model class's search" do
        @mock_model_class.expects(:search).returns({:foo => :bar})
        @controller.search.should == { :foo => :bar }
    end
    
    it "should delegate destroy to the indirection's model class's destroy" do
        @mock_model_class.expects(:destroy).returns({:foo => :bar})
        @controller.destroy.should == { :foo => :bar }    
    end
    
    it "should delegate save to the indirection's model class's save" do
        data = { :bar => :xyzzy }
        mock_model_instance = mock('model instance')
        @mock_model_class.expects(:new).with(data).returns(mock_model_instance)
        mock_model_instance.expects(:save).returns({:foo => :bar})
        @controller.save(data).should == { :foo => :bar }            
    end
end