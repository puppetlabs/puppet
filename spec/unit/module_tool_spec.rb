# encoding: UTF-8

require 'spec_helper'
require 'puppet/module_tool'

describe Puppet::ModuleTool, :fails_on_windows => true do
  describe '.format_tree' do
    it 'should return an empty tree when given an empty list' do
      subject.format_tree([]).should == ''
    end

    it 'should return a shallow when given a list without dependencies' do
      list = [ { :text => 'first' }, { :text => 'second' }, { :text => 'third' } ]
      subject.format_tree(list).should == <<-TREE
├── first
├── second
└── third
TREE
    end

    it 'should return a deeply nested tree when given a list with deep dependencies' do
      list = [
        {
          :text => 'first',
          :dependencies => [
            {
              :text => 'second',
              :dependencies => [
                { :text => 'third' }
              ]
            }
          ]
        },
      ]
      subject.format_tree(list).should == <<-TREE
└─┬ first
  └─┬ second
    └── third
TREE
    end

    it 'should show connectors when deep dependencies are not on the last node of the top level' do
      list = [
        {
          :text => 'first',
          :dependencies => [
            {
              :text => 'second',
              :dependencies => [
                { :text => 'third' }
              ]
            }
          ]
        },
        { :text => 'fourth' }
      ]
      subject.format_tree(list).should == <<-TREE
├─┬ first
│ └─┬ second
│   └── third
└── fourth
TREE
    end

    it 'should show connectors when deep dependencies are not on the last node of any level' do
      list = [
        {
          :text => 'first',
          :dependencies => [
            {
              :text => 'second',
              :dependencies => [
                { :text => 'third' }
              ]
            },
            { :text => 'fourth' }
          ]
        }
      ]
      subject.format_tree(list).should == <<-TREE
└─┬ first
  ├─┬ second
  │ └── third
  └── fourth
TREE
    end

    it 'should show connectors in every case when deep dependencies are not on the last node' do
      list = [
        {
          :text => 'first',
          :dependencies => [
            {
              :text => 'second',
              :dependencies => [
                { :text => 'third' }
              ]
            },
            { :text => 'fourth' }
          ]
        },
        { :text => 'fifth' }
      ]
      subject.format_tree(list).should == <<-TREE
├─┬ first
│ ├─┬ second
│ │ └── third
│ └── fourth
└── fifth
TREE
    end
  end
end
