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
    let (:puppet_settings) {
      puppet_settings = mock('Puppet::Settings')

      puppet_settings.stubs(:clear_everything_for_tests)

      Puppet.stubs(:settings).with().returns(puppet_settings)

      puppet_settings
    }

    let (:setting_values) {
      {
        # this is the default environment
        nil => {
          :environment => mock(),
          :modulepath => PuppetSpec::Files.make_absolute('/foo'),
        }
      }
    }

    def stub_puppet_settings(
      setting_values,
      default_expectations = {},
      &additional_expectations
    )
      {
        :value => true,
        :set_value => true,
      }.merge(default_expectations).each_pair do |method, flag|
        puppet_settings.stubs(method) if flag
      end

      yield puppet_settings if block_given?

      # add helper methods and setup initial setting values
      puppet_settings.instance_exec(setting_values) do |setting_values|
        @settings = setting_values

        def [](*args)
          value(*args)
        end

        def []=(*args)
          set_value(*args)
        end

        def value(param, *args)
          # let mocha check the invocation against the expectations
          method_missing(:value, param, *args)
          unless args.empty? || param == :environment
            environment = args.first
            return @settings[environment][param] if
              @settings.include?(environment) &&
              @settings[environment].include?(param)
          end
          @settings[nil][param]
        end

        def set_value(param, value, *args)
          # let mocha check the invocation against the expectations
          method_missing(:set_value, param, value, *args)
          @settings[nil][param] = value
        end
      end
    end

    describe 'option :environment' do
      context 'passed:' do
        let (:environment) { mock() }
        let (:options) { {:environment => environment} }

        it 'Puppet[:environment] should be set to the value of the option' do
          stub_puppet_settings(setting_values) do |puppet_settings|
            puppet_settings.expects(:set_value).with { |param, *args|
              param == :environment
            }
          end

          subject.set_option_defaults options

          setting_values[nil][:environment].should === environment
        end

        it 'the option value should not be overridden' do
          stub_puppet_settings(setting_values)

          subject.set_option_defaults options

          options[:environment].should === environment
        end
      end

      context 'NOT passed:' do
        let (:options) { {} }

        it 'Puppet[:environment] should NOT be overridden' do
          stub_puppet_settings(setting_values, :set_value => false) do |puppet_settings|
            puppet_settings.stubs(:set_value).with { |param, *args|
              param != :environment
            }
          end

          subject.set_option_defaults options
        end

        it 'the option should be set to the value of Puppet[:environment]' do
          stub_puppet_settings(setting_values)

          subject.set_option_defaults options

          options[:environment].should === setting_values[nil][:environment]
        end
      end
    end

    describe 'option :modulepath' do
      context 'passed:' do
        let (:modulepath) { PuppetSpec::Files.make_absolute('/bar') }
        let (:options) { {:modulepath => modulepath} }

        it 'Puppet[:modulepath] should be set to the value of the option' do
          stub_puppet_settings(setting_values) do |puppet_settings|
            puppet_settings.stubs(:set_value).with { |param, *args|
              param == :modulepath
            }
          end

          subject.set_option_defaults options

          setting_values[nil][:modulepath] === options[:modulepath]
        end

        it 'the option value should not be overridden' do
          stub_puppet_settings(setting_values)

          subject.set_option_defaults options

          options[:modulepath].should === modulepath
        end
      end

      context 'NOT passed:' do
        let (:environment_settings) {
          {
            mock() => {
              :modulepath => PuppetSpec::Files.make_absolute('/bar')
            }
          }
        }
        let (:environment) { environment_settings.keys.first }
        let (:options) { {:environment => environment} }

        before :each do
          setting_values.merge!(environment_settings)
        end

        it 'Puppet[:modulepath] should be reset to the module path of the current environment' do
          stub_puppet_settings(setting_values) do |puppet_settings|
            puppet_settings.expects(:value).with(:modulepath, environment)
            puppet_settings.expects(:set_value).with { |param, *args|
              param == :modulepath
            }
          end

          subject.set_option_defaults options

          setting_values[nil][:modulepath] === environment_settings[environment][:modulepath]
        end

        it 'the option should be set to the module path of the current environment' do
          stub_puppet_settings(setting_values)

          subject.set_option_defaults options

          options[:modulepath].should === environment_settings[environment][:modulepath]
        end
      end
    end

    describe 'option :target_dir' do
      let (:target_dir) { 'boo' }

      context 'passed:' do
        let (:options) { {:target_dir => target_dir} }

        it 'the option value should be prepended to the Puppet[:modulepath]' do
          stub_puppet_settings(setting_values, :set_value => false) do |puppet_settings|
            puppet_settings.stubs(:set_value).with { |param, *args|
              param != :modulepath
            }
            puppet_settings.expects(:set_value).with { |param, *args|
              param == :modulepath
            }.twice
          end

          original_modulepath = setting_values[nil][:modulepath]

          subject.set_option_defaults options

          setting_values[nil][:modulepath].should == options[:target_dir] + File::PATH_SEPARATOR + original_modulepath
        end

        it 'the option value should be turned into an absolute path' do
          stub_puppet_settings(setting_values)

          subject.set_option_defaults options

          options[:target_dir].should == File.expand_path(target_dir)
        end
      end

      describe 'NOT passed:' do
        let (:options) { {} }

        before :each do
          setting_values[nil][:modulepath] = 'foo' + File::PATH_SEPARATOR + 'bar'
        end

        it 'the option should be set to the first component of Puppet[:modulepath] turned into an absolute path' do
          stub_puppet_settings(setting_values)

          subject.set_option_defaults options

          options[:target_dir].should == File.expand_path(setting_values[nil][:modulepath].split(File::PATH_SEPARATOR).first)
        end
      end
    end
  end
end
