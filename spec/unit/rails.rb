#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'
require 'puppet/rails'

describe Puppet::Rails, "when initializing any connection" do
    it "should use settings" do
        Puppet.settings.expects(:use).with(:main, :rails, :puppetmasterd)
        
        Puppet::Rails.connect
    end
    
    it "should set up a logger" do
        ActiveRecord::Base.expects(:logger=)
        
        Puppet::Rails.connect
    end
    
    it "should set the log level"
    
    it "should set ActiveRecord::Base.allow_concurrency" do
        ActiveRecord::Base.expects(:allow_concurrency=).with(true)
        
        Puppet::Rails.connect
    end
    
    it "should call ActiveRecord::Base.verify_active_connections!" do
        ActiveRecord::Base.expects(:verify_active_connections!)
        
        Puppet::Rails.connect
    end
    
    it "should call ActiveRecord::Base.establish_connection with database_arguments" do
        Puppet::Rails.expects(:database_arguments)
        ActiveRecord::Base.expects(:establish_connection)
        
        Puppet::Rails.connect
    end
end

describe Puppet::Rails, "when initializing a sqlite3 connection" do
    it "should provide the adapter, log_level, and dbfile arguments" do
        Puppet.settings.expects(:value).with(:dbadapter).returns("sqlite3")
        Puppet.settings.expects(:value).with(:rails_loglevel).returns("testlevel")
        Puppet.settings.expects(:value).with(:dblocation).returns("testlocation")
        
        Puppet::Rails.database_arguments.should == {
            :adapter => "sqlite3",
            :log_level => "testlevel",
            :dbfile => "testlocation"
        }
    end
end

describe Puppet::Rails, "when initializing a mysql or postgresql connection" do
    it "should provide the adapter, log_level, and host, username, password, and database arguments" do
        Puppet.settings.expects(:value).with(:dbadapter).returns("mysql")
        Puppet.settings.expects(:value).with(:rails_loglevel).returns("testlevel")
        Puppet.settings.expects(:value).with(:dbserver).returns("testserver")
        Puppet.settings.expects(:value).with(:dbuser).returns("testuser")
        Puppet.settings.expects(:value).with(:dbpassword).returns("testpassword")
        Puppet.settings.expects(:value).with(:dbname).returns("testname")
        Puppet.settings.expects(:value).with(:dbsocket).returns("")
        
        Puppet::Rails.database_arguments.should == {
            :adapter => "mysql",
            :log_level => "testlevel",
            :host => "testserver",
            :username => "testuser",
            :password => "testpassword",
            :database => "testname"
        }
    end
    
    it "should provide the adapter, log_level, and host, username, password, database, and socket arguments" do
        Puppet.settings.expects(:value).with(:dbadapter).returns("mysql")
        Puppet.settings.expects(:value).with(:rails_loglevel).returns("testlevel")
        Puppet.settings.expects(:value).with(:dbserver).returns("testserver")
        Puppet.settings.expects(:value).with(:dbuser).returns("testuser")
        Puppet.settings.expects(:value).with(:dbpassword).returns("testpassword")
        Puppet.settings.expects(:value).with(:dbname).returns("testname")
        Puppet.settings.expects(:value).with(:dbsocket).returns("testsocket")
        
        Puppet::Rails.database_arguments.should == {
            :adapter => "mysql",
            :log_level => "testlevel",
            :host => "testserver",
            :username => "testuser",
            :password => "testpassword",
            :database => "testname",
            :socket => "testsocket"
        }
    end
end