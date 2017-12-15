#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/compiler'
require 'puppet_spec/files'
require 'puppet/pops'

module PuppetSpec::DataTypes
describe "Puppet::DataTypes" do
  include PuppetSpec::Compiler
  include PuppetSpec::Files

  let(:modules) { { 'mytest' => mytest } }
  let(:datatypes) { {} }
  let(:environments_dir) { Puppet[:environmentpath] }

  let(:mytest) {{
    'lib' => { 'puppet' => { 'functions' => { 'mytest' => mytest_functions }}}
  }}

  let(:mytest_functions) { {
    'to_data.rb' => <<-RUBY.unindent,
      Puppet::Functions.create_function('mytest::to_data') do
        def to_data(data)
          Puppet::Pops::Serialization::ToDataConverter.convert(data, {
            :rich_data => true,
            :symbol_as_string => true,
            :type_by_reference => true,
            :message_prefix => 'test'
          })
        end
      end
      RUBY

    'from_data.rb' => <<-RUBY.unindent,
      Puppet::Functions.create_function('mytest::from_data') do
        def from_data(data)
          Puppet::Pops::Serialization::FromDataConverter.convert(data)
        end
      end
      RUBY

    'serialize.rb' => <<-RUBY.unindent,
      Puppet::Functions.create_function('mytest::serialize') do
        def serialize(data)
          buffer = ''
          serializer = Puppet::Pops::Serialization::Serializer.new(
            Puppet::Pops::Serialization::JSON::Writer.new(buffer))
          serializer.write(data)
          serializer.finish
          buffer
        end
      end
      RUBY

    'deserialize.rb' => <<-RUBY.unindent,
      Puppet::Functions.create_function('mytest::deserialize') do
        def deserialize(data)
          deserializer = Puppet::Pops::Serialization::Deserializer.new(
            Puppet::Pops::Serialization::JSON::Reader.new(data), Puppet::Pops::Loaders.find_loader(nil))
          deserializer.read
        end
      end
      RUBY
  } }

  let(:testing_env_dir) do
    dir_contained_in(environments_dir, testing_env)
    env_dir = File.join(environments_dir, 'testing')
    PuppetSpec::Files.record_tmp(env_dir)
    env_dir
  end

  let(:modules_dir) { File.join(testing_env_dir, 'modules') }
  let(:env) { Puppet::Node::Environment.create(:testing, [modules_dir]) }
  let(:node) { Puppet::Node.new('test', :environment => env) }

  let(:testing_env) do
    {
      'testing' => {
        'lib' => { 'puppet' => { 'datatypes' => datatypes } },
        'modules' => modules,
      }
    }
  end

  context 'when creating type with derived attributes using implementation' do
    let(:datatypes) {
      {
        'mytype.rb' => <<-RUBY.unindent,
          Puppet::DataTypes.create_type('Mytype') do
            interface <<-PUPPET
              attributes => {
                name => { type => String },
                year_of_birth => { type => Integer },
                age => { type => Integer, kind => derived },
              }
              PUPPET

            implementation do
              def age
                DateTime.now.year - @year_of_birth
              end
            end
          end
          RUBY
      }
    }

    it 'loads and returns value of attribute' do
      expect(eval_and_collect_notices('notice(Mytype("Bob", 1984).age)', node)).to eql(["#{DateTime.now.year - 1984}"])
    end

    it 'can convert value to and from data' do
      expect(eval_and_collect_notices(<<-PUPPET.unindent, node)).to eql(['false', 'true', 'true', "#{DateTime.now.year - 1984}"])
        $m = Mytype("Bob", 1984)
        $d = $m.mytest::to_data
        notice($m == $d)
        notice($d =~ Data)
        $m2 = $d.mytest::from_data
        notice($m == $m2)
        notice($m2.age)
      PUPPET
    end
  end

  context 'when creating type for an already implemented class' do
    let(:datatypes) {
      {
        'mytest.rb' => <<-RUBY.unindent,
          Puppet::DataTypes.create_type('Mytest') do
            interface <<-PUPPET
              attributes => {
                name => { type => String },
                year_of_birth => { type => Integer },
                age => { type => Integer, kind => derived },
              },
              functions => {
                '[]' => Callable[[String[1]], Variant[String, Integer]]
              }
              PUPPET

            implementation_class PuppetSpec::DataTypes::MyTest
          end
      RUBY
      }
    }

    before(:each) do
      class ::PuppetSpec::DataTypes::MyTest
        attr_reader :name, :year_of_birth

        def initialize(name, year_of_birth)
          @name = name
          @year_of_birth = year_of_birth
        end

        def age
          DateTime.now.year - @year_of_birth
        end

        def [](key)
          case key
          when 'name'
            @name
          when 'year_of_birth'
            @year_of_birth
          when 'age'
            age
          else
            nil
          end
        end

        def ==(o)
          self.class == o.class && @name == o.name && @year_of_birth == o.year_of_birth
        end
      end
    end

    after(:each) do
      ::PuppetSpec::DataTypes.send(:remove_const, :MyTest)
    end

    it 'loads and returns value of attribute' do
      expect(eval_and_collect_notices('notice(Mytest("Bob", 1984).age)', node)).to eql(["#{DateTime.now.year - 1984}"])
    end

    it 'can convert value to and from data' do
      expect(eval_and_collect_notices(<<-PUPPET.unindent, node)).to eql(['true', 'true', "#{DateTime.now.year - 1984}"])
        $m = Mytest("Bob", 1984)
        $d = $m.mytest::to_data
        notice($d =~ Data)
        $m2 = $d.mytest::from_data
        notice($m == $m2)
        notice($m2.age)
        PUPPET
    end

    it 'can access using implemented [] method' do
      expect(eval_and_collect_notices(<<-PUPPET.unindent, node)).to eql(['Bob', "#{DateTime.now.year - 1984}"])
        $m = Mytest("Bob", 1984)
        notice($m['name'])
        notice($m['age'])
      PUPPET
    end

    it 'can serialize and deserialize data' do
      expect(eval_and_collect_notices(<<-PUPPET.unindent, node)).to eql(['true', 'true', "#{DateTime.now.year - 1984}"])
        $m = Mytest("Bob", 1984)
        $d = $m.mytest::serialize
        notice($d =~ String)
        $m2 = $d.mytest::deserialize
        notice($m == $m2)
        notice($m2.age)
        PUPPET
    end
  end
end
end
