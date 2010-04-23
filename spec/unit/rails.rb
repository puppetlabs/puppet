#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'
require 'puppet/rails'

describe Puppet::Rails, "when initializing any connection" do
    confine "Cannot test without ActiveRecord" => Puppet.features.rails?

    before do
        Puppet.settings.stubs(:use)
        @logger = mock 'logger'
        @logger.stub_everything
        Logger.stubs(:new).returns(@logger)

        ActiveRecord::Base.stubs(:logger).returns(@logger)
        ActiveRecord::Base.stubs(:connected?).returns(false)
    end

    it "should use settings" do
        Puppet.settings.expects(:use).with(:main, :rails, :puppetmasterd)

        Puppet::Rails.connect
    end

    it "should set up a logger with the appropriate Rails log file" do
        logger = mock 'logger'
        Logger.expects(:new).with(Puppet[:railslog]).returns(logger)
        ActiveRecord::Base.expects(:logger=).with(logger)

        Puppet::Rails.connect
    end

    it "should set the log level to whatever the value is in the settings" do
        Puppet.settings.stubs(:use)
        Puppet.settings.stubs(:value).with(:rails_loglevel).returns("debug")
        Puppet.settings.stubs(:value).with(:railslog).returns("/my/file")
        logger = mock 'logger'
        Logger.stubs(:new).returns(logger)
        ActiveRecord::Base.stubs(:logger).returns(logger)
        logger.expects(:level=).with(Logger::DEBUG)

        ActiveRecord::Base.stubs(:allow_concurrency=)
        ActiveRecord::Base.stubs(:verify_active_connections!)
        ActiveRecord::Base.stubs(:establish_connection)
        Puppet::Rails.stubs(:database_arguments).returns({})

        Puppet::Rails.connect
    end

    describe "on ActiveRecord 2.1.x" do
        confine "ActiveRecord 2.1.x" => (::ActiveRecord::VERSION::MAJOR == 2 and ::ActiveRecord::VERSION::MINOR <= 1)

        it "should set ActiveRecord::Base.allow_concurrency" do
            ActiveRecord::Base.expects(:allow_concurrency=).with(true)

            Puppet::Rails.connect
        end
    end

    it "should call ActiveRecord::Base.verify_active_connections!" do
        ActiveRecord::Base.expects(:verify_active_connections!)

        Puppet::Rails.connect
    end

    it "should call ActiveRecord::Base.establish_connection with database_arguments" do
        Puppet::Rails.expects(:database_arguments).returns({})
        ActiveRecord::Base.expects(:establish_connection)

        Puppet::Rails.connect
    end
end

describe Puppet::Rails, "when initializing a sqlite3 connection" do
    confine "Cannot test without ActiveRecord" => Puppet.features.rails?

    it "should provide the adapter, log_level, and database arguments" do
        Puppet.settings.expects(:value).with(:dbadapter).returns("sqlite3")
        Puppet.settings.expects(:value).with(:rails_loglevel).returns("testlevel")
        Puppet.settings.expects(:value).with(:dblocation).returns("testlocation")

        Puppet::Rails.database_arguments.should == {
            :adapter   => "sqlite3",
            :log_level => "testlevel",
            :database  => "testlocation"
        }
    end
end

describe Puppet::Rails, "when initializing a mysql connection" do
    confine "Cannot test without ActiveRecord" => Puppet.features.rails?

    it "should provide the adapter, log_level, and host, port, username, password, database, and reconnect arguments" do
        Puppet.settings.stubs(:value).with(:dbadapter).returns("mysql")
        Puppet.settings.stubs(:value).with(:rails_loglevel).returns("testlevel")
        Puppet.settings.stubs(:value).with(:dbserver).returns("testserver")
        Puppet.settings.stubs(:value).with(:dbport).returns("")
        Puppet.settings.stubs(:value).with(:dbuser).returns("testuser")
        Puppet.settings.stubs(:value).with(:dbpassword).returns("testpassword")
        Puppet.settings.stubs(:value).with(:dbname).returns("testname")
        Puppet.settings.stubs(:value).with(:dbsocket).returns("")
        Puppet.settings.stubs(:value).with(:dbconnections).returns(1)

        Puppet::Rails.database_arguments.should == {
            :adapter => "mysql",
            :log_level => "testlevel",
            :host => "testserver",
            :username => "testuser",
            :password => "testpassword",
            :database => "testname",
            :reconnect => true,
            :pool => 1
        }
    end

    it "should provide the adapter, log_level, and host, port, username, password, database, socket, connections, and reconnect arguments" do
        Puppet.settings.stubs(:value).with(:dbadapter).returns("mysql")
        Puppet.settings.stubs(:value).with(:rails_loglevel).returns("testlevel")
        Puppet.settings.stubs(:value).with(:dbserver).returns("testserver")
        Puppet.settings.stubs(:value).with(:dbport).returns("9999")
        Puppet.settings.stubs(:value).with(:dbuser).returns("testuser")
        Puppet.settings.stubs(:value).with(:dbpassword).returns("testpassword")
        Puppet.settings.stubs(:value).with(:dbname).returns("testname")
        Puppet.settings.stubs(:value).with(:dbsocket).returns("testsocket")
        Puppet.settings.stubs(:value).with(:dbconnections).returns(1)

        Puppet::Rails.database_arguments.should == {
            :adapter => "mysql",
            :log_level => "testlevel",
            :host => "testserver",
            :port => "9999",
            :username => "testuser",
            :password => "testpassword",
            :database => "testname",
            :socket => "testsocket",
            :reconnect => true,
            :pool => 1
        }
    end

    it "should provide the adapter, log_level, and host, port, username, password, database, socket, and connections arguments" do
        Puppet.settings.stubs(:value).with(:dbadapter).returns("mysql")
        Puppet.settings.stubs(:value).with(:rails_loglevel).returns("testlevel")
        Puppet.settings.stubs(:value).with(:dbserver).returns("testserver")
        Puppet.settings.stubs(:value).with(:dbport).returns("9999")
        Puppet.settings.stubs(:value).with(:dbuser).returns("testuser")
        Puppet.settings.stubs(:value).with(:dbpassword).returns("testpassword")
        Puppet.settings.stubs(:value).with(:dbname).returns("testname")
        Puppet.settings.stubs(:value).with(:dbsocket).returns("testsocket")
        Puppet.settings.stubs(:value).with(:dbconnections).returns(1)

        Puppet::Rails.database_arguments.should == {
            :adapter => "mysql",
            :log_level => "testlevel",
            :host => "testserver",
            :port => "9999",
            :username => "testuser",
            :password => "testpassword",
            :database => "testname",
            :socket => "testsocket",
            :reconnect => true,
            :pool => 1
        }
    end
end

describe Puppet::Rails, "when initializing a postgresql connection" do
    confine "Cannot test without ActiveRecord" => Puppet.features.rails?

    it "should provide the adapter, log_level, and host, port, username, password, connections, and database arguments" do
        Puppet.settings.stubs(:value).with(:dbadapter).returns("postgresql")
        Puppet.settings.stubs(:value).with(:rails_loglevel).returns("testlevel")
        Puppet.settings.stubs(:value).with(:dbserver).returns("testserver")
        Puppet.settings.stubs(:value).with(:dbport).returns("9999")
        Puppet.settings.stubs(:value).with(:dbuser).returns("testuser")
        Puppet.settings.stubs(:value).with(:dbpassword).returns("testpassword")
        Puppet.settings.stubs(:value).with(:dbname).returns("testname")
        Puppet.settings.stubs(:value).with(:dbsocket).returns("")
        Puppet.settings.stubs(:value).with(:dbconnections).returns(1) 

        Puppet::Rails.database_arguments.should == {
            :adapter => "postgresql",
            :log_level => "testlevel",
            :host => "testserver",
            :port => "9999",
            :username => "testuser",
            :password => "testpassword",
            :database => "testname",
            :reconnect => true,
            :pool => 1
        }
    end

    it "should provide the adapter, log_level, and host, port, username, password, database, connections, and socket arguments" do
        Puppet.settings.stubs(:value).with(:dbadapter).returns("postgresql")
        Puppet.settings.stubs(:value).with(:rails_loglevel).returns("testlevel")
        Puppet.settings.stubs(:value).with(:dbserver).returns("testserver")
        Puppet.settings.stubs(:value).with(:dbport).returns("9999")
        Puppet.settings.stubs(:value).with(:dbuser).returns("testuser")
        Puppet.settings.stubs(:value).with(:dbpassword).returns("testpassword")
        Puppet.settings.stubs(:value).with(:dbname).returns("testname")
        Puppet.settings.stubs(:value).with(:dbsocket).returns("testsocket")
        Puppet.settings.stubs(:value).with(:dbconnections).returns(1)

        Puppet::Rails.database_arguments.should == {
            :adapter => "postgresql",
            :log_level => "testlevel",
            :host => "testserver",
            :port => "9999",
            :username => "testuser",
            :password => "testpassword",
            :database => "testname",
            :socket => "testsocket",
            :pool => 1,
            :reconnect => true
        }
    end
end

describe Puppet::Rails, "when initializing an Oracle connection" do
    confine "Cannot test without ActiveRecord" => Puppet.features.rails?

    it "should provide the adapter, log_level, and username, password, dbconnections, and database arguments" do
        Puppet.settings.stubs(:value).with(:dbadapter).returns("oracle_enhanced")
        Puppet.settings.stubs(:value).with(:rails_loglevel).returns("testlevel")
        Puppet.settings.stubs(:value).with(:dbuser).returns("testuser")
        Puppet.settings.stubs(:value).with(:dbpassword).returns("testpassword")
        Puppet.settings.stubs(:value).with(:dbname).returns("testname")
        Puppet.settings.stubs(:value).with(:dbconnections).returns(1) 

        Puppet::Rails.database_arguments.should == {
            :adapter => "oracle_enhanced",
            :log_level => "testlevel",
            :username => "testuser",
            :password => "testpassword",
            :database => "testname",
            :pool => 1
        }
    end

    it "should provide the adapter, log_level, and host, username, password, database, pool, and socket arguments" do
        Puppet.settings.stubs(:value).with(:dbadapter).returns("oracle_enhanced")
        Puppet.settings.stubs(:value).with(:rails_loglevel).returns("testlevel")
        Puppet.settings.stubs(:value).with(:dbuser).returns("testuser")
        Puppet.settings.stubs(:value).with(:dbpassword).returns("testpassword")
        Puppet.settings.stubs(:value).with(:dbname).returns("testname")
        Puppet.settings.stubs(:value).with(:dbconnections).returns(1)

        Puppet::Rails.database_arguments.should == {
            :adapter => "oracle_enhanced",
            :log_level => "testlevel",
            :username => "testuser",
            :password => "testpassword",
            :database => "testname",
            :pool => 1 
        }
    end
end
