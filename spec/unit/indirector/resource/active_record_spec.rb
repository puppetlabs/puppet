#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/rails'
require 'puppet/node/facts'

describe "Puppet::Resource::ActiveRecord", :if => Puppet.features.rails? do
  include PuppetSpec::Files

  before :each do
    dir = Pathname(tmpdir('puppet-var'))
    Puppet[:vardir]       = dir.to_s
    Puppet[:dbadapter]    = 'sqlite3'
    Puppet[:dblocation]   = (dir + 'storeconfigs.sqlite').to_s
    Puppet[:storeconfigs] = true
  end

  after :each do
    ActiveRecord::Base.remove_connection
  end

  subject {
    require 'puppet/indirector/resource/active_record'
    Puppet::Resource.indirection.terminus(:active_record)
  }

  it "should automatically initialize Rails" do
    # Other tests in the suite may have established the connection, which will
    # linger; the assertion is just to enforce our assumption about the call,
    # not because I *really* want to test ActiveRecord works.  Better to have
    # an early failure than wonder why the test overall doesn't DTRT.
    ActiveRecord::Base.remove_connection
    ActiveRecord::Base.should_not be_connected
    subject.should be
    ActiveRecord::Base.should be_connected
  end

  describe "#search" do
    before :each do Puppet::Rails.init end

    def search(type, host = 'default.local', filter = nil)
      args = { :host => host, :filter => filter }
      subject.search(Puppet::Resource.indirection.request(:search, type, args))
    end

    it "should fail if the type is not known to Puppet" do
      expect { search("banana") }.to raise_error Puppet::Error, /Could not find type/
    end

    it "should return an empty array if no resources match" do
      search("exec").should == []
    end

    context "with a matching resource" do
      before :each do
        host = Puppet::Rails::Host.create!(:name => 'one.local')
        Puppet::Rails::Resource.
          create!(:host     => host,
                  :restype  => 'exec', :title => 'whammo',
                  :exported => true)

      end

      it "should return something responding to `to_resource` if a resource matches" do
        found = search("exec")
        found.length.should == 1
        found.map do |item|
          item.should respond_to :to_resource
          item.restype.should == "exec"
        end
      end

      it "should not filter resources that have been found before" do
        search("exec").should == search("exec")
      end
    end
  end

  describe "#build_active_record_query" do
    before :each do
      Puppet::Rails.init
    end

    let :type do
      Puppet::Type.type('notify').name
    end

    def query(type, host, filter = nil)
      subject.send :build_active_record_query, type, host, filter
    end

    it "should exclude all database resources from the host" do
      host = Puppet::Rails::Host.create! :name => 'one.local'
      got = query(type, host.name)
      got.keys.should =~ [:conditions]
      got[:conditions][0] =~ /\(host_id != \?\)/
      got[:conditions].last.should == host.id
    end

    it "should join appropriately when filtering on parameters" do
      filter = "param_names.name = title"
      got = query(type, 'whatever', filter)
      got.keys.should =~ [:conditions, :joins]
      got[:joins].should == { :param_values => :param_name }
      got[:conditions].first.should =~ Regexp.new(Regexp.escape(filter))
    end

    it "should join appropriately when filtering on tags" do
      filter = "puppet_tags.name = test"
      got = query(type, 'whatever', filter)
      got.keys.should =~ [:conditions, :joins]
      got[:joins].should == {:resource_tags => :puppet_tag}
      got[:conditions].first.should =~ Regexp.new(Regexp.escape(filter))
    end

    it "should only search for exported resources with the matching type" do
      got = query(type, 'whatever')
      got.keys.should =~ [:conditions]
      got[:conditions][0].should be_include "(exported=? AND restype=?)"
      got[:conditions][1].should == true
      got[:conditions][2].should == type
    end
  end
end
