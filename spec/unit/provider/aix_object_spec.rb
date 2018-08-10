require 'spec_helper'
require 'puppet/provider/aix_object'

describe 'Puppet::Provider::AixObject' do
  let(:resource) do
    Puppet::Type.type(:user).new(
      :name   => 'test_aix_user',
      :ensure => :present
    )
  end
  let(:klass) { Puppet::Provider::AixObject }
  let(:provider) do
    Puppet::Provider::AixObject.new(resource)
  end

  # Clear out the class-level + instance-level mappings
  def clear_attributes
    klass.instance_variable_set(:@mappings, nil)
  end

  before(:each) do
    clear_attributes
  end

  describe '.mapping' do
    let(:puppet_property) { :uid }
    let(:aix_attribute) { :id }
    let(:info) do
      {
        :puppet_property => puppet_property,
        :aix_attribute   => aix_attribute
      }
    end

    shared_examples 'a mapping' do |from, to|
      context "<#{from}> => <#{to}>" do
        let(:from_suffix) { from.to_s.split("_")[-1] }
        let(:to_suffix)   { to.to_s.split("_")[-1] }
        let(:conversion_fn) do
          "convert_#{from_suffix}_value".to_sym
        end

        it 'creates the mapping for a pure conversion function and defines it' do
          conversion_fn_lambda = "#{from_suffix}_to_#{to_suffix}".to_sym
          info[conversion_fn_lambda] = lambda { |x| x.to_s }
          provider.class.mapping(info)
    
          mappings = provider.class.mappings[to]
          expect(mappings).to include(info[from])

          mapping = mappings[info[from]]
          expect(mapping.public_methods).to include(conversion_fn)

          expect(mapping.send(conversion_fn, 3)).to eql('3')
        end

        it 'creates the mapping for an impure conversion function without defining it' do
          conversion_fn_lambda = "#{from_suffix}_to_#{to_suffix}".to_sym
          info[conversion_fn_lambda] = lambda { |provider, x| x.to_s }
          provider.class.mapping(info)
    
          mappings = provider.class.mappings[to]
          expect(mappings).to include(info[from])

          mapping = mappings[info[from]]
          expect(mapping.public_methods).not_to include(conversion_fn)
        end
  
        it 'uses the identity function as the conversion function if none is provided' do
          provider.class.mapping(info)

    
          mappings = provider.class.mappings[to]
          expect(mappings).to include(info[from])

          mapping = mappings[info[from]]
          expect(mapping.public_methods).to include(conversion_fn)

          expect(mapping.send(conversion_fn, 3)).to eql(3)
        end
      end
    end

    include_examples 'a mapping',
                     :puppet_property,
                     :aix_attribute

    include_examples 'a mapping',
                     :aix_attribute,
                     :puppet_property

    it 'sets the AIX attribute to the Puppet property if it is not provided' do
      info[:aix_attribute] = nil
      provider.class.mapping(info)

      mappings = provider.class.mappings[:puppet_property]
      expect(mappings).to include(info[:puppet_property])
    end
  end

  describe '.numeric_mapping' do
    let(:info) do
      info_hash = {
        :puppet_property => :uid,
        :aix_attribute   => :id
      }
      provider.class.numeric_mapping(info_hash)

      info_hash
    end
    let(:aix_attribute) do
      provider.class.mappings[:aix_attribute][info[:puppet_property]]
    end
    let(:puppet_property) do
      provider.class.mappings[:puppet_property][info[:aix_attribute]]
    end

    it 'raises an ArgumentError for a non-numeric Puppet property value' do
      value = 'foo'
      expect do
        aix_attribute.convert_property_value(value) 
      end.to raise_error do |error|
        expect(error).to be_a(ArgumentError)

        expect(error.message).to match(value)
        expect(error.message).to match(info[:puppet_property].to_s)
      end
    end

    it 'converts the numeric Puppet property to a numeric AIX attribute' do
      expect(aix_attribute.convert_property_value(10)).to eql('10')
    end

    it 'converts the numeric AIX attribute to a numeric Puppet property' do
      expect(puppet_property.convert_attribute_value('10')).to eql(10)
    end
  end

  describe '.mk_resource_methods' do
    before(:each) do
      # Add some Puppet properties
      provider.class.mapping(
        puppet_property: :foo,
        aix_attribute: :foo
      )
      provider.class.mapping(
        puppet_property: :bar,
        aix_attribute: :bar
      )

      provider.class.mk_resource_methods
    end

    it 'defines the property getters' do
      provider = Puppet::Provider::AixObject.new(resource)
      provider.instance_variable_set(:@object_info, { :foo => 'foo', :baz => 'baz' })

      (provider.class.mappings[:aix_attribute].keys + [:attributes]).each do |property|
        provider.expects(:get).with(property).returns('value')

        expect(provider.send(property)).to eql('value')
      end
    end

    it 'defines the property setters' do
      provider = Puppet::Provider::AixObject.new(resource)

      value = '15'
      provider.class.mappings[:aix_attribute].keys.each do |property|
        provider.expects(:set).with(property, value)

        provider.send("#{property}=".to_sym, value)
      end
    end
  end

  describe '.parse_colon_separated_list' do
    it 'parses a single empty item' do
      input = ''
      output = ['']

      expect(provider.class.parse_colon_separated_list(input)).to eql(output)
    end

    it 'parses a single nonempty item' do
      input = 'item'
      output = ['item']

      expect(provider.class.parse_colon_separated_list(input)).to eql(output)
    end

    it "parses an escaped ':'" do
      input = '#!:'
      output = [':']

      expect(provider.class.parse_colon_separated_list(input)).to eql(output)
    end

    it "parses a single item with an escaped ':'" do
      input = 'fd8c#!:215d#!:178#!:'
      output = ['fd8c:215d:178:']

      expect(provider.class.parse_colon_separated_list(input)).to eql(output)
    end

    it "parses multiple items that do not have an escaped ':'" do
      input = "foo:bar baz:buu:1234"
      output = ["foo", "bar baz", "buu", "1234"]

      expect(provider.class.parse_colon_separated_list(input)).to eql(output)
    end

    it "parses multiple items some of which have escaped ':'" do
      input = "1234#!:567:foo bar#!:baz:buu#!bob:sally:fd8c#!:215d#!:178"
      output = ["1234:567", "foo bar:baz", "buu#!bob", "sally", 'fd8c:215d:178']

      expect(provider.class.parse_colon_separated_list(input)).to eql(output)
    end

    it "parses a list with several empty items" do
      input = "foo:::bar:baz:boo:"
      output = ["foo", "", "", "bar", "baz", "boo", ""]

      expect(provider.class.parse_colon_separated_list(input)).to eql(output)
    end

    it "parses a list with an escaped ':' and empty item at the end" do
      input = "foo:bar#!::"
      output = ["foo", "bar:", ""]

      expect(provider.class.parse_colon_separated_list(input)).to eql(output)
    end

    it 'parses a real world example' do
      input = File.read(my_fixture('aix_colon_list_real_world_input.out')).chomp
      output = Object.instance_eval(File.read(my_fixture('aix_colon_list_real_world_output.out')))

      expect(provider.class.parse_colon_separated_list(input)).to eql(output)
    end
  end

  describe '.parse_aix_objects' do
    # parse_colon_separated_list is well tested, so we don't need to be
    # as strict on the formatting of the output here. Main point of these
    # tests is to capture the 'wholemeal' parsing that's going on, i.e.
    # that we can parse a bunch of objects together.
    let(:output) do
      <<-AIX_OBJECTS
#name:id:pgrp:groups
root:0:system:system,bin,sys,security,cron,audit,lp
#name:id:pgrp:groups:home:gecos
user:10000:staff:staff:/home/user3:Some User
AIX_OBJECTS
    end

    let(:expected_aix_attributes) do
      [
        {
          :name => 'root',
          :attributes => {
            :id     => '0',
            :pgrp   => 'system',
            :groups => 'system,bin,sys,security,cron,audit,lp',
          }
        },
        {
          :name => 'user',
          :attributes => {
            :id     => '10000',
            :pgrp   => 'staff',
            :groups => 'staff',
            :home   => '/home/user3',
            :gecos  => 'Some User'
          }
        }
      ]
    end

    it 'parses the AIX attributes from the command output' do
      expect(provider.class.parse_aix_objects(output)).to eql(expected_aix_attributes)
    end
  end

  describe 'list_all' do
    let(:output) do
      <<-OUTPUT
#name:id
system:0
#name:id
staff:1
#name:id
bin:2
      OUTPUT
    end

    it 'lists all of the objects' do
      lscmd = 'lsgroups'
      provider.class.stubs(:command).with(:list).returns(lscmd)
      provider.class.stubs(:execute).with([lscmd, '-c', '-a', 'id', 'ALL']).returns(output)

      expected_objects = [
        { :name => 'system', :id => '0' },
        { :name => 'staff', :id => '1' },
        { :name => 'bin', :id => '2' }
      ]
      expect(provider.class.list_all).to eql(expected_objects)
    end
  end

  describe '.instances' do
    let(:objects) do
      [
        { :name => 'group1', :id => '1' },
        { :name => 'group2', :id => '2' }
      ]
    end

    it 'returns all of the available instances' do
      provider.class.stubs(:list_all).returns(objects)

      expect(provider.class.instances.map(&:name)).to eql(['group1', 'group2'])
    end
  end

  describe '#mappings' do
    # Returns a pair [ instance_level_mapped_object, class_level_mapped_object ]
    def mapped_objects(type, input)
      [
        provider.mappings[type][input],
        provider.class.mappings[type][input]
      ]
    end

    before(:each) do
      # Create a pure mapping
      provider.class.numeric_mapping(
        puppet_property: :pure_puppet_property,
        aix_attribute: :pure_aix_attribute
      )

      # Create an impure mapping
      impure_conversion_fn = lambda do |provider, value|
        "Provider instance's name is #{provider.name}"
      end
      provider.class.mapping(
        puppet_property: :impure_puppet_property,
        aix_attribute: :impure_aix_attribute,
        property_to_attribute: impure_conversion_fn,
        attribute_to_property: impure_conversion_fn
      )
    end

    it 'memoizes the result' do
      provider.instance_variable_set(:@mappings, 'memoized')
      expect(provider.mappings).to eql('memoized')
    end

    it 'creates the instance-level mappings with the same structure as the class-level one' do
      expect(provider.mappings.keys).to eql(provider.class.mappings.keys)
      provider.mappings.keys.each do |type|
        expect(provider.mappings[type].keys).to eql(provider.class.mappings[type].keys)
      end
    end
    
    shared_examples 'uses the right mapped object for a given mapping' do |from_type, to_type|
      context "<#{from_type}> => <#{to_type}>" do
        it 'shares the class-level mapped object for pure mappings' do
          input = "pure_#{from_type}".to_sym

          instance_level_mapped_object, class_level_mapped_object = mapped_objects(to_type, input)
          expect(instance_level_mapped_object.object_id).to eql(class_level_mapped_object.object_id)
        end

        it 'dups the class-level mapped object for impure mappings' do
          input = "impure_#{from_type}".to_sym

          instance_level_mapped_object, class_level_mapped_object = mapped_objects(to_type, input)
          expect(instance_level_mapped_object.object_id).to_not eql(
            class_level_mapped_object.object_id
          )
        end

        it 'defines the conversion function for impure mappings' do
          from_type_suffix = from_type.to_s.split("_")[-1]
          conversion_fn = "convert_#{from_type_suffix}_value".to_sym

          input = "impure_#{from_type}".to_sym
          mapped_object, _ = mapped_objects(to_type, input)

          expect(mapped_object.public_methods).to include(conversion_fn)
          expect(mapped_object.send(conversion_fn, 3)).to match(provider.name)
        end
      end
    end

    include_examples 'uses the right mapped object for a given mapping',
                     :puppet_property,
                     :aix_attribute

    include_examples 'uses the right mapped object for a given mapping',
                     :aix_attribute,
                     :puppet_property
  end

  describe '#attributes_to_args' do
    let(:attributes) do
      {
        :attribute1 => 'value1',
        :attribute2 => 'value2'
      }
    end

    it 'converts the attributes hash to CLI arguments' do
      expect(provider.attributes_to_args(attributes)).to eql(
        ["attribute1=value1", "attribute2=value2"]
      )
    end
  end

  describe '#ia_module_args' do
    it 'returns no arguments if the ia_load_module parameter is not specified' do
      provider.resource.stubs(:[]).with(:ia_load_module).returns(nil)
      expect(provider.ia_module_args).to eql([])
    end

    it 'returns the ia_load_module as a CLI argument' do
      provider.resource.stubs(:[]).with(:ia_load_module).returns('module')
      expect(provider.ia_module_args).to eql(['-R', 'module'])
    end
  end

  describe '#lscmd' do
    it 'returns the lscmd' do
      provider.class.stubs(:command).with(:list).returns('list')
      provider.stubs(:ia_module_args).returns(['ia_module_args'])

      expect(provider.lscmd).to eql(
        ['list', '-c', 'ia_module_args', provider.resource.name]
      )
    end
  end

  describe '#addcmd' do
    let(:attributes) do
      {
        :attribute1 => 'value1',
        :attribute2 => 'value2'
      }
    end

    it 'returns the addcmd passing in the attributes as CLI arguments' do
      provider.class.stubs(:command).with(:add).returns('add')
      provider.stubs(:ia_module_args).returns(['ia_module_args'])

      expect(provider.addcmd(attributes)).to eql(
        ['add', 'ia_module_args', 'attribute1=value1', 'attribute2=value2', provider.resource.name]
      )
    end
  end

  describe '#deletecmd' do
    it 'returns the lscmd' do
      provider.class.stubs(:command).with(:delete).returns('delete')
      provider.stubs(:ia_module_args).returns(['ia_module_args'])

      expect(provider.deletecmd).to eql(
        ['delete', 'ia_module_args', provider.resource.name]
      )
    end
  end

  describe '#modifycmd' do
    let(:attributes) do
      {
        :attribute1 => 'value1',
        :attribute2 => 'value2'
      }
    end

    it 'returns the addcmd passing in the attributes as CLI arguments' do
      provider.class.stubs(:command).with(:modify).returns('modify')
      provider.stubs(:ia_module_args).returns(['ia_module_args'])

      expect(provider.modifycmd(attributes)).to eql(
        ['modify', 'ia_module_args', 'attribute1=value1', 'attribute2=value2', provider.resource.name]
      )
    end
  end

  describe '#modify_object' do
    let(:new_attributes) do
      {
        :nofiles => 10000,
        :fsize   => 30000
      }
    end

    it 'modifies the AIX object with the new attributes' do
      provider.stubs(:modifycmd).with(new_attributes).returns('modify_cmd')
      provider.expects(:execute).with('modify_cmd')
      provider.expects(:object_info).with(true)

      provider.modify_object(new_attributes)
    end
  end

  describe '#get' do
    # Input
    let(:property) { :uid }
    
    let!(:object_info) do
      hash = {}

      provider.instance_variable_set(:@object_info, hash)
      hash
    end

    it 'returns :absent if the AIX object does not exist' do
      provider.stubs(:exists?).returns(false)
      object_info[property] = 15
      
      expect(provider.get(property)).to eql(:absent)
    end

    it 'returns :absent if the property is not present on the system' do
      provider.stubs(:exists?).returns(true)

      expect(provider.get(property)).to eql(:absent)
    end

    it "returns the property's value" do
      provider.stubs(:exists?).returns(true)
      object_info[property] = 15

      expect(provider.get(property)).to eql(15)
    end
  end

  describe '#set' do
    # Input
    let(:property) { :uid }
    let(:value) { 10 }

    # AIX attribute params
    let(:aix_attribute) { :id }
    let(:property_to_attribute) do
      lambda { |x| x.to_s }
    end

    before(:each) do
      # Add an attribute
      provider.class.mapping(
        puppet_property: property,
        aix_attribute: aix_attribute,
        property_to_attribute: property_to_attribute
      )
    end

    it "raises a Puppet::Error if it fails to set the property's value" do
      provider.stubs(:modify_object)
        .with({ :id => value.to_s })
        .raises(Puppet::ExecutionFailure, 'failed to modify the AIX object!')

      expect { provider.set(property, value) }.to raise_error do |error|
        expect(error).to be_a(Puppet::Error)
      end
    end

    it "sets the given property's value to the passed-in value" do
      provider.expects(:modify_object).with({ :id => value.to_s })

      provider.set(property, value)
    end
  end

  describe '#validate_new_attributes' do
    let(:new_attributes) do
      {
        :nofiles => 10000,
        :fsize   => 100000
      }
    end

    it 'raises a Puppet::Error if a specified attributes corresponds to a Puppet property, reporting all of the attribute-property conflicts' do
      provider.class.mapping(puppet_property: :uid, aix_attribute: :id)
      provider.class.mapping(puppet_property: :groups, aix_attribute: :groups)

      new_attributes[:id] = '25'
      new_attributes[:groups] = 'groups'

      expect { provider.validate_new_attributes(new_attributes) }.to raise_error do |error|
        expect(error).to be_a(Puppet::Error)

        expect(error.message).to match("'uid', 'groups'")
        expect(error.message).to match("'id', 'groups'")
      end
    end
  end

  describe '#attributes=' do
    let(:new_attributes) do
      {
        :nofiles => 10000,
        :fsize   => 100000
      }
    end

    it 'raises a Puppet::Error if one of the specified attributes corresponds to a Puppet property' do
      provider.class.mapping(puppet_property: :uid, aix_attribute: :id)
      new_attributes[:id] = '25'

      expect { provider.attributes = new_attributes }.to raise_error do |error|
        expect(error).to be_a(Puppet::Error)

        expect(error.message).to match('uid')
        expect(error.message).to match('id')
      end
    end

    it 'raises a Puppet::Error if it fails to set the new AIX attributes' do
      provider.stubs(:modify_object)
        .with(new_attributes)
        .raises(Puppet::ExecutionFailure, 'failed to modify the AIX object!')
      
      expect { provider.attributes = new_attributes }.to raise_error do |error|
        expect(error).to be_a(Puppet::Error)

        expect(error.message).to match('failed to modify the AIX object!')
      end
    end

    it 'sets the new AIX attributes' do
      provider.expects(:modify_object).with(new_attributes)

      provider.attributes = new_attributes
    end
  end

  describe '#object_info' do
    before(:each) do
      # Add some Puppet properties
      provider.class.mapping(
        puppet_property: :uid,
        aix_attribute: :id,
        attribute_to_property: lambda { |x| x.to_i },
      )
      provider.class.mapping(
        puppet_property: :groups,
        aix_attribute: :groups
      )

      # Mock out our lscmd
      provider.stubs(:lscmd).returns("lsuser #{resource[:name]}")
    end

    it 'memoizes the result' do
      provider.instance_variable_set(:@object_info, {})
      expect(provider.object_info).to eql({})
    end

    it 'returns nil if the AIX object does not exist' do
      provider.stubs(:execute).with(provider.lscmd).raises(
        Puppet::ExecutionFailure, 'lscmd failed!'
      )

      expect(provider.object_info).to be_nil
    end

    it 'collects the Puppet properties' do
      output = 'mock_output'
      provider.stubs(:execute).with(provider.lscmd).returns(output)

      # Mock the AIX attributes on the system
      mock_attributes = {
        :id         => '1',
        :groups     => 'foo,bar,baz',
        :attribute1 => 'value1',
        :attribute2 => 'value2'
      }
      provider.class.stubs(:parse_aix_objects)
        .with(output)
        .returns([{ :name => resource.name, :attributes => mock_attributes }])

      expected_property_values = {
        :uid        => 1,
        :groups     => 'foo,bar,baz',
        :attributes => {
          :attribute1 => 'value1',
          :attribute2 => 'value2'
        }
      }
      provider.object_info
      expect(provider.instance_variable_get(:@object_info)).to eql(expected_property_values)
    end
  end

  describe '#exists?' do
    it 'should return true if the AIX object exists' do
      provider.stubs(:object_info).returns({})
      expect(provider.exists?).to be(true)
    end

    it 'should return false if the AIX object does not exist' do
      provider.stubs(:object_info).returns(nil)
      expect(provider.exists?).to be(false)
    end
  end

  describe "#create" do
    let(:property_attributes) do
      {}
    end
    def stub_attributes_property(attributes)
      provider.resource.stubs(:should).with(:attributes).returns(attributes)
    end
    def set_property(puppet_property, aix_attribute, property_to_attribute, should_value = nil)
      property_to_attribute ||= lambda { |x| x }

      provider.class.mapping(
        puppet_property: puppet_property,
        aix_attribute: aix_attribute,
        property_to_attribute: property_to_attribute
      )
      provider.resource.stubs(:should).with(puppet_property).returns(should_value)

      if should_value
        property_attributes[aix_attribute] = property_to_attribute.call(should_value)
      end
    end

    before(:each) do
      clear_attributes
      
      # Clear out the :attributes property. We will be setting this later.
      stub_attributes_property(nil)

      # Add some properties
      set_property(:uid, :id, lambda { |x| x.to_s }, 10)
      set_property(:groups, :groups, nil, 'group1,group2,group3')
      set_property(:shell, :shell, nil)
    end

    it 'raises a Puppet::Error if one of the specified attributes corresponds to a Puppet property' do
      stub_attributes_property({ :id => 15 })
      provider.class.mapping(puppet_property: :uid, aix_attribute: :id)

      expect { provider.create }.to raise_error do |error|
        expect(error).to be_a(Puppet::Error)

        expect(error.message).to match('uid')
        expect(error.message).to match('id')
      end
    end

    it "raises a Puppet::Error if it fails to create the AIX object" do
      provider.stubs(:addcmd)
      provider.stubs(:execute).raises(
        Puppet::ExecutionFailure, "addcmd failed!"
      )

      expect { provider.create }.to raise_error do |error|
        expect(error).to be_a(Puppet::Error)

        expect(error.message).to match("not create")
      end
    end

    it "creates the AIX object with the given AIX attributes + Puppet properties" do
      attributes = { :fsize => 1000 }
      stub_attributes_property(attributes)

      provider.expects(:addcmd)
        .with(attributes.merge(property_attributes))
        .returns('addcmd')
      provider.expects(:execute).with('addcmd')

      provider.create
    end
  end
 
  describe "#delete" do
    before(:each) do
      provider.stubs(:deletecmd).returns('deletecmd')
    end

    it "raises a Puppet::Error if it fails to delete the AIX object" do
      provider.stubs(:execute).with(provider.deletecmd).raises(
        Puppet::ExecutionFailure, "deletecmd failed!"
      )

      expect { provider.delete }.to raise_error do |error|
        expect(error).to be_a(Puppet::Error)

        expect(error.message).to match("not delete")
      end
    end

    it "deletes the AIX object" do
      provider.expects(:execute).with(provider.deletecmd)
      provider.expects(:object_info).with(true)

      provider.delete
    end
  end
end
