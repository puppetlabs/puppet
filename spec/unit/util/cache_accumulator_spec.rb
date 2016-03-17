#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/util/rails/cache_accumulator'

describe Puppet::Util::CacheAccumulator do
  before :each do
    @test_class = Class.new do
      attr_accessor :name

      include Puppet::Util::CacheAccumulator
      accumulates :name

      def initialize(n)
        self.name = n
      end
    end
  end

  it 'should delegate to underlying find_or_create_by_* method and accumulate results' do
    @test_class.expects(:find_or_create_by_name).with('foo').returns(@test_class.new('foo')).once
    obj = @test_class.accumulate_by_name('foo')
    obj.name.should == 'foo'
    @test_class.accumulate_by_name('foo').should == obj
  end

  it 'should delegate bulk lookups to find with appropriate arguments and returning result count' do

    @test_class.expects(:find).with(
      :all,

        :conditions => {:name => ['a', 'b', 'c']}
          ).returns(['a','b','c'].collect {|n| @test_class.new(n)}).once
    @test_class.accumulate_by_name('a', 'b', 'c').should == 3
  end

  it 'should only need find_or_create_by_name lookup for missing bulk entries' do

    @test_class.expects(:find).with(
      :all,

        :conditions => {:name => ['a', 'b']}
          ).returns([ @test_class.new('a') ]).once
    @test_class.expects(:find_or_create_by_name).with('b').returns(@test_class.new('b')).once
    @test_class.expects(:find_or_create_by_name).with('a').never
    @test_class.accumulate_by_name('a','b').should == 1
    @test_class.accumulate_by_name('a').name.should == 'a'
    @test_class.accumulate_by_name('b').name.should == 'b'
  end

  it 'should keep consumer classes separate' do
    @alt_class = Class.new do
      attr_accessor :name

      include Puppet::Util::CacheAccumulator
      accumulates :name

      def initialize(n)
        self.name = n
      end
    end
    name = 'foo'
    @test_class.expects(:find_or_create_by_name).with(name).returns(@test_class.new(name)).once
    @alt_class.expects(:find_or_create_by_name).with(name).returns(@alt_class.new(name)).once

    [@test_class, @alt_class].each do |klass|
      klass.accumulate_by_name(name).name.should == name
      klass.accumulate_by_name(name).class.should == klass
    end
  end

  it 'should clear accumulated cache with reset_*_accumulator' do
    # figure out how to test this appropriately...
  end
end
