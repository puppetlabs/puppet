#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'
require 'puppet/rails'

describe Puppet::Rails, " when using sqlite3" do
    setup do
        @old_adapter    = Puppet[:dbadapter]
        @old_dbsocket = Puppet[:dbsocket]
        
        Puppet[:dbadapter] = "sqlite3"
    end
    
    teardown do
        Puppet[:dbadapter] = @old_adapter
        Puppet[:dbsocket]  = @old_dbsocket
    end
    
    it "should ignore the database socket argument" do
        Puppet[:dbsocket] = "blah"
        Puppet::Rails.database_arguments[:socket].should be_nil
    end
end

describe Puppet::Rails, " when not using sqlite3" do
    setup do
        @old_adapter  = Puppet[:dbadapter]
        @old_dbsocket = Puppet[:dbsocket]
        
        Puppet[:dbadapter] = "mysql"
    end
    
    teardown do
        Puppet[:dbadapter] = @old_adapter
        Puppet[:dbsocket]  = @old_dbsocket
    end
    
    it "should set the dbsocket argument if not empty " do
        Puppet[:dbsocket] = "blah"
        Puppet::Rails.database_arguments[:socket].should == "blah"
    end
    
    it "should not set the dbsocket argument if empty" do
        Puppet[:dbsocket] = ""
        Puppet::Rails.database_arguments[:socket].should be_nil
    end
end