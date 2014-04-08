#! /usr/bin/env ruby
# encoding: UTF-8

require 'spec_helper'
require 'puppet/module_tool'

describe Puppet::ModuleTool do
  describe '.is_module_root?' do
    it 'should return true if directory has a module file' do
      FileTest.expects(:file?).with(responds_with(:to_s, '/a/b/c/Modulefile')).
        returns(true)

      subject.is_module_root?(Pathname.new('/a/b/c')).should be_true
    end

    it 'should return false if directory does not have a module file' do
      FileTest.expects(:file?).with(responds_with(:to_s, '/a/b/c/Modulefile')).
        returns(false)

      subject.is_module_root?(Pathname.new('/a/b/c')).should be_false
    end
  end

  describe '.find_module_root' do
    let(:sample_path) { Pathname.new('/a/b/c').expand_path }

    it 'should return the first path as a pathname when it contains a module file' do
      Puppet::ModuleTool.expects(:is_module_root?).with(sample_path).
        returns(true)

      subject.find_module_root(sample_path).should == sample_path
    end

    it 'should return a parent path as a pathname when it contains a module file' do
      Puppet::ModuleTool.expects(:is_module_root?).
        with(responds_with(:to_s, File.expand_path('/a/b/c'))).returns(false)
      Puppet::ModuleTool.expects(:is_module_root?).
        with(responds_with(:to_s, File.expand_path('/a/b'))).returns(true)

      subject.find_module_root(sample_path).should == Pathname.new('/a/b').expand_path
    end

    it 'should return nil when no module root can be found' do
      Puppet::ModuleTool.expects(:is_module_root?).at_least_once.returns(false)
      subject.find_module_root(sample_path).should be_nil
    end
  end

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

  describe '.set_option_defaults' do
    let(:options) { {} }
    let(:modulepath) { [File.expand_path('/env/module/path'), File.expand_path('/global/module/path')] }
    let(:environment) { Puppet::Node::Environment.create('current', modulepath) }
    around(:each) do |example|
      Puppet.override(:current_environment => environment) do
        example.run
      end
    end

    describe 'option :environment_instance' do
      it 'adds an environment_instance to the options hash' do
        subject.set_option_defaults(options)
        expect(options[:environment_instance].name).to eq(environment.name)
        expect(options[:environment_instance].modulepath).to eq(environment.modulepath)
      end
    end

    describe 'option :target_dir' do
      let (:target_dir) { 'boo' }

      context 'passed:' do
        let (:options) { {:target_dir => target_dir} }

        it 'prepends the target_dir into the environment_instance modulepath' do
          subject.set_option_defaults options

          expect(options[:environment_instance].full_modulepath).
            to eq([File.expand_path(target_dir)] + modulepath)
        end

        it 'expands the target dir' do
          subject.set_option_defaults options

          options[:target_dir].should == File.expand_path(target_dir)
        end
      end

      context 'NOT passed:' do
        it 'the option should be set to the first component of Puppet[:modulepath]' do
          options = Hash.new
          subject.set_option_defaults options

          expect(options[:target_dir]).to eq(environment.full_modulepath.first)
        end
      end
    end
  end
end
