#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/util/queue'

def make_test_client_class(n)
  c = Class.new do
    class <<self
      attr_accessor :name
      def to_s
        name
      end
    end
  end
  c.name = n
  c
end

mod = Puppet::Util::Queue
client_classes = { :default => make_test_client_class('Bogus::Default'), :setup => make_test_client_class('Bogus::Setup') }

describe Puppet::Util::Queue do
  before :all do
    mod.register_queue_type(client_classes[:default], :default)
    mod.register_queue_type(client_classes[:setup], :setup)
  end

  before :each do
    @class = Class.new do
      extend mod
    end
  end

  after :all do
    instances = mod.instance_hash(:queue_clients)
    [:default, :setup, :bogus, :aardvark, :conflict, :test_a, :test_b].each{ |x| instances.delete(x) }
  end

  context 'when determining a type name from a class' do
    it 'should handle a simple one-word class name' do
      mod.queue_type_from_class(make_test_client_class('Foo')).should == :foo
    end

    it 'should handle a simple two-word class name' do
      mod.queue_type_from_class(make_test_client_class('FooBar')).should == :foo_bar
    end

    it 'should handle a two-part class name with one terminating word' do
      mod.queue_type_from_class(make_test_client_class('Foo::Bar')).should == :bar
    end

    it 'should handle a two-part class name with two terminating words' do
      mod.queue_type_from_class(make_test_client_class('Foo::BarBah')).should == :bar_bah
    end
  end

  context 'when registering a queue client class' do
    c = make_test_client_class('Foo::Bogus')
    it 'uses the proper default name logic when type is unspecified' do
      mod.register_queue_type(c)
      mod.queue_type_to_class(:bogus).should == c
    end

    it 'uses an explicit type name when provided' do
      mod.register_queue_type(c, :aardvark)
      mod.queue_type_to_class(:aardvark).should == c
    end

    it 'throws an exception when type names conflict' do
      mod.register_queue_type( make_test_client_class('Conflict') )
      lambda { mod.register_queue_type( c, :conflict) }.should raise_error
    end

    it 'handle multiple, non-conflicting registrations' do
      a = make_test_client_class('TestA')
      b = make_test_client_class('TestB')
      mod.register_queue_type(a)
      mod.register_queue_type(b)
      mod.queue_type_to_class(:test_a).should == a
      mod.queue_type_to_class(:test_b).should == b
    end

    it 'throws an exception when type name is unknown' do
      lambda { mod.queue_type_to_class(:nope) }.should raise_error
    end
  end

  context 'when determining client type' do
    it 'returns client class based on the :queue_type setting' do
      Puppet[:queue_type] = :myqueue
      Puppet::Util::Queue.expects(:queue_type_to_class).with(:myqueue).returns "eh"
      @class.client_class.should == "eh"
    end
  end
end
