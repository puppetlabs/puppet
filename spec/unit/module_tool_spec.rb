#! /usr/bin/env ruby
# encoding: UTF-8

require 'spec_helper'
require 'puppet/module_tool'

describe Puppet::ModuleTool do
  describe '.is_module_root?' do
    it 'should return true if directory has a metadata.json file' do
      FileTest.expects(:file?).with(responds_with(:to_s, '/a/b/c/metadata.json')).
        returns(true)

      expect(subject.is_module_root?(Pathname.new('/a/b/c'))).to be_truthy
    end

    it 'should return false if directory does not have a metadata.json file' do
      FileTest.expects(:file?).with(responds_with(:to_s, '/a/b/c/metadata.json')).
        returns(false)

      expect(subject.is_module_root?(Pathname.new('/a/b/c'))).to be_falsey
    end
  end

  describe '.find_module_root' do
    let(:sample_path) { Pathname.new('/a/b/c').expand_path }

    it 'should return the first path as a pathname when it contains a module file' do
      Puppet::ModuleTool.expects(:is_module_root?).with(sample_path).
        returns(true)

      expect(subject.find_module_root(sample_path)).to eq(sample_path)
    end

    it 'should return a parent path as a pathname when it contains a module file' do
      Puppet::ModuleTool.expects(:is_module_root?).
        with(responds_with(:to_s, File.expand_path('/a/b/c'))).returns(false)
      Puppet::ModuleTool.expects(:is_module_root?).
        with(responds_with(:to_s, File.expand_path('/a/b'))).returns(true)

      expect(subject.find_module_root(sample_path)).to eq(Pathname.new('/a/b').expand_path)
    end

    it 'should return nil when no module root can be found' do
      Puppet::ModuleTool.expects(:is_module_root?).at_least_once.returns(false)
      expect(subject.find_module_root(sample_path)).to be_nil
    end
  end

  describe '.format_tree' do
    it 'should return an empty tree when given an empty list' do
      expect(subject.format_tree([])).to eq('')
    end

    it 'should return a shallow when given a list without dependencies' do
      list = [ { :text => 'first' }, { :text => 'second' }, { :text => 'third' } ]
      expect(subject.format_tree(list)).to eq <<-TREE
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
      expect(subject.format_tree(list)).to eq <<-TREE
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
      expect(subject.format_tree(list)).to eq <<-TREE
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
      expect(subject.format_tree(list)).to eq <<-TREE
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
      expect(subject.format_tree(list)).to eq <<-TREE
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
    let(:modulepath) { ['/env/module/path', '/global/module/path'] }
    let(:environment_name) { :current_environment }
    let(:environment) { Puppet::Node::Environment.create(environment_name, modulepath) }

    subject do
      described_class.set_option_defaults(options)
      options
    end

    around do |example|
      envs = Puppet::Environments::Static.new(environment)

      Puppet.override(:environments => envs) do
        example.run
      end
    end

    describe ':environment' do
      context 'as String' do
        let(:options) { { :environment => "#{environment_name}" } }

        it 'assigns the environment with the given name to :environment_instance' do
          expect(subject).to include :environment_instance => environment
        end
      end

      context 'as Symbol' do
        let(:options) { { :environment => :"#{environment_name}" } }

        it 'assigns the environment with the given name to :environment_instance' do
          expect(subject).to include :environment_instance => environment
        end
      end

      context 'as Puppet::Node::Environment' do
        let(:env) { Puppet::Node::Environment.create('anonymous', []) }
        let(:options) { { :environment => env } }

        it 'assigns the given environment to :environment_instance' do
          expect(subject).to include :environment_instance => env
        end
      end
    end

    describe ':modulepath' do
      let(:options) do
        { :modulepath => %w[bar foo baz].join(File::PATH_SEPARATOR) }
      end

      let(:paths) { options[:modulepath].split(File::PATH_SEPARATOR).map { |dir| File.expand_path(dir) } }

      it 'is expanded to an absolute path' do
        expect(subject[:environment_instance].full_modulepath).to eql paths
      end

      it 'is used to compute :target_dir' do
        expect(subject).to include :target_dir => paths.first
      end

      context 'conflicts with :environment' do
        let(:options) do
          { :modulepath => %w[bar foo baz].join(File::PATH_SEPARATOR), :environment => environment_name }
        end

        it 'replaces the modulepath of the :environment_instance' do
          expect(subject[:environment_instance].full_modulepath).to eql paths
        end

        it 'is used to compute :target_dir' do
          expect(subject).to include :target_dir => paths.first
        end
      end
    end

    describe ':target_dir' do
      let(:options) do
        { :target_dir => 'foo' }
      end

      let(:target) { File.expand_path(options[:target_dir]) }

      it 'is expanded to an absolute path' do
        expect(subject).to include :target_dir => target
      end

      it 'is prepended to the modulepath of the :environment_instance' do
        expect(subject[:environment_instance].full_modulepath.first).to eql target
      end

      context 'conflicts with :modulepath' do
        let(:options) do
          { :target_dir => 'foo', :modulepath => %w[bar foo baz].join(File::PATH_SEPARATOR) }
        end

        it 'is prepended to the modulepath of the :environment_instance' do
          expect(subject[:environment_instance].full_modulepath.first).to eql target
        end

        it 'shares the provided :modulepath via the :environment_instance' do
          paths = %w[foo] + options[:modulepath].split(File::PATH_SEPARATOR)
          paths.map! { |dir| File.expand_path(dir) }
          expect(subject[:environment_instance].full_modulepath).to eql paths
        end
      end

      context 'conflicts with :environment' do
        let(:options) do
          { :target_dir => 'foo', :environment => environment_name }
        end

        it 'is prepended to the modulepath of the :environment_instance' do
          expect(subject[:environment_instance].full_modulepath.first).to eql target
        end

        it 'shares the provided :modulepath via the :environment_instance' do
          paths = %w[foo] + environment.full_modulepath
          paths.map! { |dir| File.expand_path(dir) }
          expect(subject[:environment_instance].full_modulepath).to eql paths
        end
      end

      context 'when not passed' do
        it 'is populated with the first component of the modulepath' do
          expect(subject).to include :target_dir => subject[:environment_instance].full_modulepath.first
        end
      end
    end
  end

  describe '.parse_module_dependency' do
    it 'parses a dependency without a version range expression' do
      name, range, expr = subject.parse_module_dependency('source', 'name' => 'foo-bar')
      expect(name).to eql('foo-bar')
      expect(range).to eql(Semantic::VersionRange.parse('>= 0.0.0'))
      expect(expr).to eql('>= 0.0.0')
    end

    it 'parses a dependency with a version range expression' do
      name, range, expr = subject.parse_module_dependency('source', 'name' => 'foo-bar', 'version_requirement' => '1.2.x')
      expect(name).to eql('foo-bar')
      expect(range).to eql(Semantic::VersionRange.parse('1.2.x'))
      expect(expr).to eql('1.2.x')
    end

    it 'does not raise an error on invalid version range expressions' do
      name, range, expr = subject.parse_module_dependency('source', 'name' => 'foo-bar', 'version_requirement' => 'nope')
      expect(name).to eql('foo-bar')
      expect(range).to eql(Semantic::VersionRange::EMPTY_RANGE)
      expect(expr).to eql('nope')
    end
  end
end
