#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/parameter'

describe Puppet::Parameter do
  before do
    @class = Class.new(Puppet::Parameter) do
      @name = :foo
    end
    @class.initvars
    @resource = mock 'resource'
    @resource.stub_everything
    @parameter = @class.new :resource => @resource
  end

  it "should create a value collection" do
    @class = Class.new(Puppet::Parameter)
    expect(@class.value_collection).to be_nil
    @class.initvars
    expect(@class.value_collection).to be_instance_of(Puppet::Parameter::ValueCollection)
  end

  it "should return its name as a string when converted to a string" do
    expect(@parameter.to_s).to eq(@parameter.name.to_s)
  end

  [:line, :file, :version].each do |data|
    it "should return its resource's #{data} as its #{data}" do
      @resource.expects(data).returns "foo"
      expect(@parameter.send(data)).to eq("foo")
    end
  end

  it "should return the resource's tags plus its name as its tags" do
    @resource.expects(:tags).returns %w{one two}
    expect(@parameter.tags).to eq(%w{one two foo})
  end

  it "should have a path" do
    expect(@parameter.path).to eq("//foo")
  end

  describe "when returning the value" do
    it "should return nil if no value is set" do
      expect(@parameter.value).to be_nil
    end

    it "should validate the value" do
      @parameter.expects(:validate).with("foo")
      @parameter.value = "foo"
    end

    it "should munge the value and use any result as the actual value" do
      @parameter.expects(:munge).with("foo").returns "bar"
      @parameter.value = "foo"
      expect(@parameter.value).to eq("bar")
    end

    it "should unmunge the value when accessing the actual value" do
      @parameter.class.unmunge do |value| value.to_sym end
      @parameter.value = "foo"
      expect(@parameter.value).to eq(:foo)
    end

    it "should return the actual value by default when unmunging" do
      expect(@parameter.unmunge("bar")).to eq("bar")
    end

    it "should return any set value" do
      @parameter.value = "foo"
      expect(@parameter.value).to eq("foo")
    end
  end

  describe "when validating values" do
    it "should do nothing if no values or regexes have been defined" do
      @parameter.validate("foo")
    end

    it "should catch abnormal failures thrown during validation" do
      @class.validate { |v| raise "This is broken" }
      expect { @parameter.validate("eh") }.to raise_error(Puppet::DevError)
    end

    it "should fail if the value is not a defined value or alias and does not match a regex" do
      @class.newvalues :foo
      expect { @parameter.validate("bar") }.to raise_error(Puppet::Error)
    end

    it "should succeed if the value is one of the defined values" do
      @class.newvalues :foo
      expect { @parameter.validate(:foo) }.to_not raise_error
    end

    it "should succeed if the value is one of the defined values even if the definition uses a symbol and the validation uses a string" do
      @class.newvalues :foo
      expect { @parameter.validate("foo") }.to_not raise_error
    end

    it "should succeed if the value is one of the defined values even if the definition uses a string and the validation uses a symbol" do
      @class.newvalues "foo"
      expect { @parameter.validate(:foo) }.to_not raise_error
    end

    it "should succeed if the value is one of the defined aliases" do
      @class.newvalues :foo
      @class.aliasvalue :bar, :foo
      expect { @parameter.validate("bar") }.to_not raise_error
    end

    it "should succeed if the value matches one of the regexes" do
      @class.newvalues %r{\d}
      expect { @parameter.validate("10") }.to_not raise_error
    end
  end

  describe "when munging values" do
    it "should do nothing if no values or regexes have been defined" do
      expect(@parameter.munge("foo")).to eq("foo")
    end

    it "should catch abnormal failures thrown during munging" do
      @class.munge { |v| raise "This is broken" }
      expect { @parameter.munge("eh") }.to raise_error(Puppet::DevError)
    end

    it "should return return any matching defined values" do
      @class.newvalues :foo, :bar
      expect(@parameter.munge("foo")).to eq(:foo)
    end

    it "should return any matching aliases" do
      @class.newvalues :foo
      @class.aliasvalue :bar, :foo
      expect(@parameter.munge("bar")).to eq(:foo)
    end

    it "should return the value if it matches a regex" do
      @class.newvalues %r{\w}
      expect(@parameter.munge("bar")).to eq("bar")
    end

    it "should return the value if no other option is matched" do
      @class.newvalues :foo
      expect(@parameter.munge("bar")).to eq("bar")
    end
  end

  describe "when logging" do
    it "should use its resource's log level and the provided message" do
      @resource.expects(:[]).with(:loglevel).returns :notice
      @parameter.expects(:send_log).with(:notice, "mymessage")
      @parameter.log "mymessage"
    end
  end

  describe ".format_value_for_display" do
    it 'should format strings appropriately' do
      expect(described_class.format_value_for_display('foo')).to eq("'foo'")
    end

    it 'should format numbers appropriately' do
      expect(described_class.format_value_for_display(1)).to eq('1')
    end

    it 'should format symbols appropriately' do
      expect(described_class.format_value_for_display(:bar)).to eq("'bar'")
    end

    it 'should format arrays appropriately' do
      expect(described_class.format_value_for_display([1, 'foo', :bar])).to eq("[1, 'foo', 'bar']")
    end

    it 'should format hashes appropriately' do
      expect(described_class.format_value_for_display(
        {1 => 'foo', :bar => 2, 'baz' => :qux}
      )).to eq(<<-RUBY.unindent.sub(/\n$/, ''))
        {
          1 => 'foo',
          'bar' => 2,
          'baz' => 'qux'
        }
      RUBY
    end

    it 'should format arrays with nested data appropriately' do
      expect(described_class.format_value_for_display(
        [1, 'foo', :bar, [1, 2, 3], {1 => 2, 3 => 4}]
      )).to eq(<<-RUBY.unindent.sub(/\n$/, ''))
        [1, 'foo', 'bar',
          [1, 2, 3],
          {
            1 => 2,
            3 => 4
          }]
      RUBY
    end

    it 'should format hashes with nested data appropriately' do
      expect(described_class.format_value_for_display(
        {1 => 'foo', :bar => [2, 3, 4], 'baz' => {:qux => 1, :quux => 'two'}}
      )).to eq(<<-RUBY.unindent.sub(/\n$/, ''))
        {
          1 => 'foo',
          'bar' => [2, 3, 4],
          'baz' => {
            'qux' => 1,
            'quux' => 'two'
          }
        }
       RUBY
    end

    it 'should format hashes with nested Objects appropriately' do
      tf = Puppet::Pops::Types::TypeFactory
      type = tf.object({'name' => 'MyType', 'attributes' => { 'qux' => tf.integer, 'quux' => tf.string }})
      expect(described_class.format_value_for_display(
        {1 => 'foo', 'bar' => type.create(1, 'one'), 'baz' => type.create(2, 'two')}
      )).to eq(<<-RUBY.unindent.sub(/\n$/, ''))
        {
          1 => 'foo',
          'bar' => MyType({
            'qux' => 1,
            'quux' => 'one'
          }),
          'baz' => MyType({
            'qux' => 2,
            'quux' => 'two'
          })
        }
      RUBY
    end

    it 'should format Objects with nested Objects appropriately' do
      tf = Puppet::Pops::Types::TypeFactory
      inner_type = tf.object({'name' => 'MyInnerType', 'attributes' => { 'qux' => tf.integer, 'quux' => tf.string }})
      outer_type = tf.object({'name' => 'MyOuterType', 'attributes' => { 'x' => tf.string, 'inner' => inner_type }})
      expect(described_class.format_value_for_display(
        {'bar' => outer_type.create('a', inner_type.create(1, 'one')), 'baz' => outer_type.create('b', inner_type.create(2, 'two'))}
      )).to eq(<<-RUBY.unindent.sub(/\n$/, ''))
        {
          'bar' => MyOuterType({
            'x' => 'a',
            'inner' => MyInnerType({
              'qux' => 1,
              'quux' => 'one'
            })
          }),
          'baz' => MyOuterType({
            'x' => 'b',
            'inner' => MyInnerType({
              'qux' => 2,
              'quux' => 'two'
            })
          })
        }
      RUBY
    end
  end

  describe 'formatting messages' do
    it "formats messages as-is when the parameter is not sensitive" do
      expect(@parameter.format("hello %s", "world")).to eq("hello world")
    end

    it "formats messages with redacted values when the parameter is not sensitive" do
      @parameter.sensitive = true
      expect(@parameter.format("hello %s", "world")).to eq("hello [redacted]")
    end
  end
end
