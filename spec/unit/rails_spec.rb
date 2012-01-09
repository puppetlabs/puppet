#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/rails'

describe Puppet::Rails, "when initializing any connection", :if => Puppet.features.rails? do
  before do
    Puppet.settings.stubs(:use)
    @logger = mock 'logger'
    @logger.stub_everything
    Logger.stubs(:new).returns(@logger)

    ActiveRecord::Base.stubs(:logger).returns(@logger)
    ActiveRecord::Base.stubs(:connected?).returns(false)
  end

  it "should use settings" do
    Puppet.settings.expects(:use).with(:main, :rails, :master)

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

  describe "ActiveRecord Version" do
    it "should set ActiveRecord::Base.allow_concurrency if ActiveRecord is 2.1" do
      Puppet::Util.stubs(:activerecord_version).returns(2.1)
      ActiveRecord::Base.expects(:allow_concurrency=).with(true)

      Puppet::Rails.connect
    end

    it "should not set ActiveRecord::Base.allow_concurrency if ActiveRecord is >= 2.2" do
      Puppet::Util.stubs(:activerecord_version).returns(2.2)
      ActiveRecord::Base.expects(:allow_concurrency=).never

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

describe Puppet::Rails, "when initializing a sqlite3 connection", :if => Puppet.features.rails? do
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

['mysql','mysql2','postgresql'].each do |dbadapter|
  describe Puppet::Rails, "when initializing a #{dbadapter} connection", :if => Puppet.features.rails? do
    it "should provide the adapter, log_level, and host, port, username, password, database, and reconnect arguments" do
      Puppet.settings.stubs(:value).with(:dbadapter).returns(dbadapter)
      Puppet.settings.stubs(:value).with(:rails_loglevel).returns("testlevel")
      Puppet.settings.stubs(:value).with(:dbserver).returns("testserver")
      Puppet.settings.stubs(:value).with(:dbport).returns("")
      Puppet.settings.stubs(:value).with(:dbuser).returns("testuser")
      Puppet.settings.stubs(:value).with(:dbpassword).returns("testpassword")
      Puppet.settings.stubs(:value).with(:dbconnections).returns((pool_size = 45).to_s)
      Puppet.settings.stubs(:value).with(:dbname).returns("testname")
      Puppet.settings.stubs(:value).with(:dbsocket).returns("")

      Puppet::Rails.database_arguments.should == {
        :adapter => dbadapter,
        :log_level => "testlevel",
        :host => "testserver",
        :username => "testuser",
        :password => "testpassword",
        :pool => pool_size,
        :database => "testname",
        :reconnect => true
      }
    end

    it "should provide the adapter, log_level, and host, port, username, password, database, socket, connections, and reconnect arguments" do
      Puppet.settings.stubs(:value).with(:dbadapter).returns(dbadapter)
      Puppet.settings.stubs(:value).with(:rails_loglevel).returns("testlevel")
      Puppet.settings.stubs(:value).with(:dbserver).returns("testserver")
      Puppet.settings.stubs(:value).with(:dbport).returns("9999")
      Puppet.settings.stubs(:value).with(:dbuser).returns("testuser")
      Puppet.settings.stubs(:value).with(:dbpassword).returns("testpassword")
      Puppet.settings.stubs(:value).with(:dbconnections).returns((pool_size = 12).to_s)
      Puppet.settings.stubs(:value).with(:dbname).returns("testname")
      Puppet.settings.stubs(:value).with(:dbsocket).returns("testsocket")

      Puppet::Rails.database_arguments.should == {
        :adapter => dbadapter,
        :log_level => "testlevel",
        :host => "testserver",
        :port => "9999",
        :username => "testuser",
        :password => "testpassword",
        :pool => pool_size,
        :database => "testname",
        :socket => "testsocket",
        :reconnect => true
      }
    end

    it "should provide the adapter, log_level, and host, port, username, password, database, socket, and connections arguments" do
      Puppet.settings.stubs(:value).with(:dbadapter).returns(dbadapter)
      Puppet.settings.stubs(:value).with(:rails_loglevel).returns("testlevel")
      Puppet.settings.stubs(:value).with(:dbserver).returns("testserver")
      Puppet.settings.stubs(:value).with(:dbport).returns("9999")
      Puppet.settings.stubs(:value).with(:dbuser).returns("testuser")
      Puppet.settings.stubs(:value).with(:dbpassword).returns("testpassword")
      Puppet.settings.stubs(:value).with(:dbconnections).returns((pool_size = 23).to_s)
      Puppet.settings.stubs(:value).with(:dbname).returns("testname")
      Puppet.settings.stubs(:value).with(:dbsocket).returns("testsocket")

      Puppet::Rails.database_arguments.should == {
        :adapter => dbadapter,
        :log_level => "testlevel",
        :host => "testserver",
        :port => "9999",
        :username => "testuser",
        :password => "testpassword",
        :pool => pool_size,
        :database => "testname",
        :socket => "testsocket",
        :reconnect => true
      }
    end

    it "should not provide the pool if dbconnections is 0, '0', or ''" do
      Puppet.settings.stubs(:value).with(:dbadapter).returns(dbadapter)
      Puppet.settings.stubs(:value).with(:rails_loglevel).returns("testlevel")
      Puppet.settings.stubs(:value).with(:dbserver).returns("testserver")
      Puppet.settings.stubs(:value).with(:dbport).returns("9999")
      Puppet.settings.stubs(:value).with(:dbuser).returns("testuser")
      Puppet.settings.stubs(:value).with(:dbpassword).returns("testpassword")
      Puppet.settings.stubs(:value).with(:dbname).returns("testname")
      Puppet.settings.stubs(:value).with(:dbsocket).returns("testsocket")

      Puppet.settings.stubs(:value).with(:dbconnections).returns(0)
      Puppet::Rails.database_arguments.should_not be_include(:pool)

      Puppet.settings.stubs(:value).with(:dbconnections).returns('0')
      Puppet::Rails.database_arguments.should_not be_include(:pool)

      Puppet.settings.stubs(:value).with(:dbconnections).returns('')
      Puppet::Rails.database_arguments.should_not be_include(:pool)
    end
  end
end

describe Puppet::Rails, "when initializing an Oracle connection", :if => Puppet.features.rails? do
  it "should provide the adapter, log_level, and username, password, and database arguments" do
    Puppet.settings.stubs(:value).with(:dbadapter).returns("oracle_enhanced")
    Puppet.settings.stubs(:value).with(:rails_loglevel).returns("testlevel")
    Puppet.settings.stubs(:value).with(:dbuser).returns("testuser")
    Puppet.settings.stubs(:value).with(:dbpassword).returns("testpassword")
    Puppet.settings.stubs(:value).with(:dbconnections).returns((pool_size = 123).to_s)
    Puppet.settings.stubs(:value).with(:dbname).returns("testname")

    Puppet::Rails.database_arguments.should == {
      :adapter => "oracle_enhanced",
      :log_level => "testlevel",
      :username => "testuser",
      :password => "testpassword",
      :pool => pool_size,
      :database => "testname"
    }
  end

  it "should provide the adapter, log_level, and host, username, password, database and socket arguments" do
    Puppet.settings.stubs(:value).with(:dbadapter).returns("oracle_enhanced")
    Puppet.settings.stubs(:value).with(:rails_loglevel).returns("testlevel")
    Puppet.settings.stubs(:value).with(:dbuser).returns("testuser")
    Puppet.settings.stubs(:value).with(:dbpassword).returns("testpassword")
    Puppet.settings.stubs(:value).with(:dbconnections).returns((pool_size = 124).to_s)
    Puppet.settings.stubs(:value).with(:dbname).returns("testname")

    Puppet::Rails.database_arguments.should == {
      :adapter => "oracle_enhanced",
      :log_level => "testlevel",
      :username => "testuser",
      :password => "testpassword",
      :pool => pool_size,
      :database => "testname"
    }
  end

  it "should not provide the pool if dbconnections is 0, '0', or ''" do
    Puppet.settings.stubs(:value).with(:dbadapter).returns("oracle_enhanced")
    Puppet.settings.stubs(:value).with(:rails_loglevel).returns("testlevel")
    Puppet.settings.stubs(:value).with(:dbserver).returns("testserver")
    Puppet.settings.stubs(:value).with(:dbport).returns("9999")
    Puppet.settings.stubs(:value).with(:dbuser).returns("testuser")
    Puppet.settings.stubs(:value).with(:dbpassword).returns("testpassword")
    Puppet.settings.stubs(:value).with(:dbname).returns("testname")
    Puppet.settings.stubs(:value).with(:dbsocket).returns("testsocket")

    Puppet.settings.stubs(:value).with(:dbconnections).returns(0)
    Puppet::Rails.database_arguments.should_not be_include(:pool)

    Puppet.settings.stubs(:value).with(:dbconnections).returns('0')
    Puppet::Rails.database_arguments.should_not be_include(:pool)

    Puppet.settings.stubs(:value).with(:dbconnections).returns('')
    Puppet::Rails.database_arguments.should_not be_include(:pool)
  end
end
