#! /usr/bin/env ruby -S rspec
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
    let(:sample_path) { Pathname.new('/a/b/c') }

    it 'should return the first path as a pathname when it contains a module file' do
      Puppet::ModuleTool.expects(:is_module_root?).with(sample_path).
        returns(true)

      subject.find_module_root(sample_path).should == sample_path
    end

    it 'should return a parent path as a pathname when it contains a module file' do
      Puppet::ModuleTool.expects(:is_module_root?).
        with(responds_with(:to_s, '/a/b/c')).returns(false)
      Puppet::ModuleTool.expects(:is_module_root?).
        with(responds_with(:to_s, '/a/b')).returns(true)

      subject.find_module_root(sample_path).should == Pathname.new('/a/b')
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
    include PuppetSpec::Files
    let (:setting) { {:environment => "foo", :modulepath => make_absolute("foo")} }

    [:environment, :modulepath].each do |value|
      describe "if #{value} is part of options" do
        let (:options) { {} }

        before(:each) do
          options[value] = setting[value]
          Puppet[value] = "bar"
        end

        it "should set Puppet[#{value}] to the options[#{value}]" do
          subject.set_option_defaults options
          Puppet[value].should == options[value]
        end

        it "should not override options[#{value}]" do
          subject.set_option_defaults options
          options[value].should == setting[value]
        end

      end

      describe "if #{value} is not part of options" do
        let (:options) { {} }

        before(:each) do
          Puppet[value] = setting[value]
        end

        it "should populate options[#{value}] with the value of Puppet[#{value}]" do
          subject.set_option_defaults options
          Puppet[value].should == options[value]
        end

        it "should not override Puppet[#{value}]" do
          subject.set_option_defaults options
          Puppet[value].should == setting[value]
        end
      end
    end

    describe ':target_dir' do
      let (:sep) { File::PATH_SEPARATOR }

      let (:my_fake_path) {
          ["/my/fake/dir", "/my/other/dir"].collect { |dir| make_absolute(dir) } .join(sep)
      }
      let (:options) { {:modulepath => my_fake_path}}

      describe "when not specified" do

        it "should set options[:target_dir]" do
          subject.set_option_defaults options
          options[:target_dir].should_not be_nil
        end

        it "should be the first path of options[:modulepath]" do
          subject.set_option_defaults options
          options[:target_dir].should == my_fake_path.split(sep).first
        end
      end

      describe "when specified" do
        let (:my_target_dir) { make_absolute("/foo/bar") }
        before(:each) do
          options[:target_dir] = my_target_dir
        end

        it "should not be overridden" do
          subject.set_option_defaults options
          options[:target_dir].should == my_target_dir
        end

        it "should be prepended to options[:modulepath]" do
          subject.set_option_defaults options
          options[:modulepath].split(sep).first.should == my_target_dir
        end

        it "should leave the remainder of options[:modulepath] untouched" do
          subject.set_option_defaults options
          options[:modulepath].split(sep).drop(1).join(sep).should == my_fake_path
        end
      end

    end
  end
end
