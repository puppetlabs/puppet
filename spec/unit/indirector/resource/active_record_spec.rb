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
end
