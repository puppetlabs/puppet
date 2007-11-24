#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'
require 'puppet/rails'

describe Puppet::Rails, " when using sqlite3" do
    setup do
        expectation_setup
    end
    
    it "should ignore the database socket argument" do
        Puppet::Rails.database_arguments[:socket].should be_nil
    end
    
    private
        def expectation_setup(extra = {})
            arguments_and_results = {
                :dbadapter      => "sqlite3",
                :rails_loglevel => "testlevel",
                :dblocation     => "testlocation"
            }.merge(extra)
            
            arguments_and_results.each do |argument, result|
                Puppet.settings.expects(:value).with(argument).returns(result)
            end
        end
end

describe Puppet::Rails, " when not using sqlite3" do
    it "should set the dbsocket argument if not empty" do
        expectation_setup
        Puppet::Rails.database_arguments[:socket].should == "testsocket"
    end
    
    it "should not set the dbsocket argument if empty" do
        expectation_setup(:dbsocket => "")
        Puppet::Rails.database_arguments[:socket].should be_nil
    end
    
    private
        def expectation_setup(extra = {})
            arguments_and_results = {
                :dbadapter      => "mysql",
                :rails_loglevel => "testlevel",
                :dbserver       => "testserver",
                :dbuser         => "testuser",
                :dbpassword     => "testpassword",
                :dbname         => "testdb",
                :dbsocket       => "testsocket"
            }.merge(extra)
            
            arguments_and_results.each do |argument, result|
                Puppet.settings.expects(:value).with(argument).returns(result)
            end
        end
end