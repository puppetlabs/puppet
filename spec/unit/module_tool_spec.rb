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
    describe 'option :environment' do
      context 'passed:' do
        let (:environment) { "ahgkduerh" }
        let (:options) { {:environment => environment} }

        it 'Puppet[:environment] should be set to the value of the option' do
          subject.set_option_defaults options

          Puppet[:environment].should == environment
        end

        it 'the option value should not be overridden' do
          Puppet[:environment] = :foo
          subject.set_option_defaults options

          options[:environment].should == environment
        end
      end

      context 'NOT passed:' do
        it 'Puppet[:environment] should NOT be overridden' do
          Puppet[:environment] = :foo

          subject.set_option_defaults({})
          Puppet[:environment].should == :foo
        end

        it 'the option should be set to the value of Puppet[:environment]' do
          options_to_modify = Hash.new
          Puppet[:environment] = :abcdefg

          subject.set_option_defaults options_to_modify

          options_to_modify[:environment].should == :abcdefg
        end
      end
    end

    describe 'option :modulepath' do
      context 'passed:' do
        let (:modulepath) { PuppetSpec::Files.make_absolute('/bar') }
        let (:options) { {:modulepath => modulepath} }

        it 'Puppet[:modulepath] should be set to the value of the option' do

          subject.set_option_defaults options

          Puppet[:modulepath].should == modulepath
        end

        it 'the option value should not be overridden' do
          Puppet[:modulepath] = "/foo"

          subject.set_option_defaults options

          options[:modulepath].should == modulepath
        end
      end

      context 'NOT passed:' do
        let (:options) { {:environment => :pmttestenv} }

        before(:each) do
          Puppet[:modulepath] = "/no"
          Puppet[:environment] = :pmttestenv
          Puppet.settings.set_value(:modulepath,
                                    ["/foo", "/bar", "/no"].join(File::PATH_SEPARATOR),
                                    :pmttestenv)
        end

        it 'Puppet[:modulepath] should be reset to the module path of the current environment' do
          subject.set_option_defaults options

          Puppet[:modulepath].should == Puppet.settings.value(:modulepath, :pmttestenv)
        end

        it 'the option should be set to the module path of the current environment' do
          subject.set_option_defaults options

          options[:modulepath].should == Puppet.settings.value(:modulepath, :pmttestenv)
        end
      end
    end

    describe 'option :target_dir' do
      let (:target_dir) { 'boo' }

      context 'passed:' do
        let (:options) { {:target_dir => target_dir} }

        it 'the option value should be prepended to the Puppet[:modulepath]' do
          Puppet[:modulepath] = "/fuz"
          original_modulepath = Puppet[:modulepath]

          subject.set_option_defaults options

          Puppet[:modulepath].should == options[:target_dir] + File::PATH_SEPARATOR + original_modulepath
        end

        it 'the option value should be turned into an absolute path' do
          subject.set_option_defaults options

          options[:target_dir].should == File.expand_path(target_dir)
        end
      end

      describe 'NOT passed:' do
        before :each do
          Puppet[:modulepath] = 'foo' + File::PATH_SEPARATOR + 'bar'
        end

        it 'the option should be set to the first component of Puppet[:modulepath]' do
          options = Hash.new
          subject.set_option_defaults options

          options[:target_dir].should == Puppet[:modulepath].split(File::PATH_SEPARATOR)[0]
        end
      end
    end
  end
end
