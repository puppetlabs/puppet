#!/usr/bin/env rspec
require 'spec_helper'

begin
  require 'sqlite3'
rescue LoadError
end

require 'puppet/rails'
require 'puppet/node/facts'

describe "Puppet::Resource::ActiveRecord", :if => (Puppet.features.rails? and defined? SQLite3) do
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

    it "should return an empty array if no resources match" do
      search("Exec").should == []
    end

    # Assert that this is a case-insensitive rule, too.
    %w{and or AND OR And Or anD oR}.each do |op|
      it "should fail if asked to search with #{op.inspect}" do
        filter = [%w{tag == foo}, op, %w{title == bar}]
        expect { search("Notify", 'localhost', filter) }.
          to raise_error Puppet::Error, /not supported/
      end
    end

    context "with a matching resource" do
      before :each do
        host = Puppet::Rails::Host.create!(:name => 'one.local')
        Puppet::Rails::Resource.
          create!(:host     => host,
                  :restype  => 'Exec', :title => 'whammo',
                  :exported => true)

      end

      it "should return something responding to `to_resource` if a resource matches" do
        found = search("Exec")
        found.length.should == 1
        found.map do |item|
          item.should respond_to :to_resource
          item.restype.should == "Exec"
        end
      end

      it "should not filter resources that have been found before" do
        search("Exec").should == search("Exec")
      end
    end
  end

  describe "#build_active_record_query" do
    before :each do
      Puppet::Rails.init
    end

    let :type do 'Notify' end

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
      filter = %w{propname == propval}
      got = query(type, 'whatever', filter)
      got.keys.should =~ [:conditions, :joins]
      got[:joins].should == { :param_values => :param_name }
      got[:conditions][0].should =~ /param_names\.name = \?/
      got[:conditions][0].should =~ /param_values\.value = \?/
      got[:conditions].should be_include filter.first
      got[:conditions].should be_include filter.last
    end

    it "should join appropriately when filtering on tags" do
      filter = %w{tag == test}
      got = query(type, 'whatever', filter)
      got.keys.should =~ [:conditions, :joins]
      got[:joins].should == {:resource_tags => :puppet_tag}
      got[:conditions].first.should =~ /puppet_tags/
      got[:conditions].should_not be_include filter.first
      got[:conditions].should be_include filter.last
    end

    it "should only search for exported resources with the matching type" do
      got = query(type, 'whatever')
      got.keys.should =~ [:conditions]
      got[:conditions][0].should be_include "(exported=? AND restype=?)"
      got[:conditions][1].should == true
      got[:conditions][2].should == type.to_s.capitalize
    end

    it "should capitalize the type, since PGSQL is case sensitive" do
      got = query(type, 'whatever')
      got[:conditions][2].should == 'Notify'
    end
  end

  describe "#filter_to_active_record" do
    def filter_to_active_record(input)
      subject.send :filter_to_active_record, input
    end

    [nil, '', 'whatever', 12].each do |input|
      it "should fail if filter is not an array (with #{input.inspect})" do
        expect { filter_to_active_record(input) }.
          to raise_error ArgumentError, /must be arrays/
      end
    end

    # Not exhaustive, just indicative.
    ['=', '<>', '=~', '+', '-', '!'].each do |input|
      it "should fail with unexpected comparison operators (with #{input.inspect})" do
        expect { filter_to_active_record(["one", input, "two"]) }.
          to raise_error ArgumentError, /unknown operator/
      end
    end

    {
      ["title", "==", "whatever"] => ["title = ?", ["whatever"]],
      ["title", "!=", "whatever"] => ["title != ?", ["whatever"]],

      # Technically, these are not supported by Puppet yet, but as we pay
      # approximately zero cost other than a few minutes writing the tests,
      # and it would be *harder* to fail on them, nested queries.
      [["title", "==", "foo"], "or", ["title", "==", "bar"]] =>
        ["(title = ?) OR (title = ?)", ["foo", "bar"]],

      [["title", "==", "foo"], "or", ["tag", "==", "bar"]] =>
        ["(title = ?) OR (puppet_tags.name = ?)", ["foo", "bar"]],

      [["title", "==", "foo"], "or", ["param", "==", "bar"]] =>
        ["(title = ?) OR (param_names.name = ? AND param_values.value = ?)",
         ["foo", "param", "bar"]],

      [[["title","==","foo"],"or",["tag", "==", "bar"]],"and",["param","!=","baz"]] =>
      ["((title = ?) OR (puppet_tags.name = ?)) AND "+
       "(param_names.name = ? AND param_values.value != ?)",
       ["foo", "bar", "param", "baz"]]

    }.each do |input, expect|
      it "should map #{input.inspect} to #{expect.inspect}" do
        filter_to_active_record(input).should == expect
      end
    end
  end
end
