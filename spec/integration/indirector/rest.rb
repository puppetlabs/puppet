require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/network/server'
require 'puppet/indirector'
require 'puppet/indirector/rest'

class Puppet::TestIndirectedFoo
  extend Puppet::Indirector  
  indirects :test_indirected_foo, :terminus_setting => :test_indirected_foo_terminus
  
  def initialize(foo)
    STDERR.puts "foo!"
  end
end

class Puppet::TestIndirectedFoo::Rest < Puppet::Indirector::REST
end

describe Puppet::Indirector::REST do
  before :each do
    Puppet::Indirector::Terminus.stubs(:terminus_class).returns(Puppet::TestIndirectedFoo::Rest)
    Puppet::TestIndirectedFoo.terminus_class = :rest
    Puppet[:servertype] = 'mongrel'
    @params = { :address => "127.0.0.1", :port => 34346, :handlers => [ :test_indirected_foo ] }
    @server = Puppet::Network::Server.new(@params)
    @server.listen
  end
  
  it "should not fail to find an instance over REST" do
    lambda { Puppet::TestIndirectedFoo.find('bar') }.should_not raise_error
  end
  
  after :each do
    @server.unlisten
  end
end