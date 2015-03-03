#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/network/formats'

class PsonTest
  attr_accessor :string
  def ==(other)
    string == other.string
  end

  def self.from_data_hash(data)
    new(data)
  end

  def initialize(string)
    @string = string
  end

  def to_pson(*args)
    {
      'type' => self.class.name,
      'data' => @string
    }.to_pson(*args)
  end
end

describe "Puppet Network Format" do
  it "should include a msgpack format", :if => Puppet.features.msgpack? do
    expect(Puppet::Network::FormatHandler.format(:msgpack)).not_to be_nil
  end

  describe "msgpack", :if => Puppet.features.msgpack? do
    before do
      @msgpack = Puppet::Network::FormatHandler.format(:msgpack)
    end

    it "should have its mime type set to application/x-msgpack" do
      expect(@msgpack.mime).to eq("application/x-msgpack")
    end

    it "should have a weight of 20" do
      expect(@msgpack.weight).to eq(20)
    end

    it "should fail when one element does not have a from_data_hash" do
      expect do
        @msgpack.intern_multiple(Hash, MessagePack.pack(["foo"]))
      end.to raise_error(NoMethodError)
    end

    it "should be able to serialize a catalog" do
      cat = Puppet::Resource::Catalog.new('foo', Puppet::Node::Environment.create(:testing, []))
      cat.add_resource(Puppet::Resource.new(:file, 'my_file'))
      catunpack = MessagePack.unpack(cat.to_msgpack)
      expect(catunpack).to include(
        "tags"=>[],
        "name"=>"foo",
        "version"=>nil,
        "environment"=>"testing",
        "edges"=>[],
        "classes"=>[]
      )
      expect(catunpack["resources"][0]).to include(
        "type"=>"File",
        "title"=>"my_file",
        "exported"=>false
      )
      expect(catunpack["resources"][0]["tags"]).to include(
        "file",
        "my_file"
      )
    end
  end

  describe "yaml" do
    before do
      @yaml = Puppet::Network::FormatHandler.format(:yaml)
    end

    it "should have its mime type set to text/yaml" do
      expect(@yaml.mime).to eq("text/yaml")
    end

    it "should be supported on Strings" do
      expect(@yaml).to be_supported(String)
    end

    it "should render by calling 'to_yaml' on the instance" do
      instance = mock 'instance'
      instance.expects(:to_yaml).returns "foo"
      expect(@yaml.render(instance)).to eq("foo")
    end

    it "should render multiple instances by calling 'to_yaml' on the array" do
      instances = [mock('instance')]
      instances.expects(:to_yaml).returns "foo"
      expect(@yaml.render_multiple(instances)).to eq("foo")
    end

    it "should deserialize YAML" do
      expect(@yaml.intern(String, YAML.dump("foo"))).to eq("foo")
    end

    it "should deserialize symbols as strings" do
      expect { @yaml.intern(String, YAML.dump(:foo))}.to raise_error(Puppet::Network::FormatHandler::FormatError)
    end

    it "should load from yaml when deserializing an array" do
      text = YAML.dump(["foo"])
      expect(@yaml.intern_multiple(String, text)).to eq(["foo"])
    end

    it "fails intelligibly instead of calling to_pson with something other than a hash" do
      expect do
        @yaml.intern(Puppet::Node, '')
      end.to raise_error(Puppet::Network::FormatHandler::FormatError, /did not contain a valid instance/)
    end

    it "fails intelligibly when intern_multiple is called and yaml doesn't decode to an array" do
      expect do
        @yaml.intern_multiple(Puppet::Node, '')
      end.to raise_error(Puppet::Network::FormatHandler::FormatError, /did not contain a collection/)
    end

    it "fails intelligibly instead of calling to_pson with something other than a hash when interning multiple" do
      expect do
        @yaml.intern_multiple(Puppet::Node, YAML.dump(["hello"]))
      end.to raise_error(Puppet::Network::FormatHandler::FormatError, /did not contain a valid instance/)
    end
  end

  describe "plaintext" do
    before do
      @text = Puppet::Network::FormatHandler.format(:s)
    end

    it "should have its mimetype set to text/plain" do
      expect(@text.mime).to eq("text/plain")
    end

    it "should use 'txt' as its extension" do
      expect(@text.extension).to eq("txt")
    end
  end

  describe "dot" do
    before do
      @dot = Puppet::Network::FormatHandler.format(:dot)
    end

    it "should have its mimetype set to text/dot" do
      expect(@dot.mime).to eq("text/dot")
    end
  end

  describe Puppet::Network::FormatHandler.format(:binary) do
    before do
      @format = Puppet::Network::FormatHandler.format(:binary)
    end

    it "should exist" do
      expect(@format).not_to be_nil
    end

    it "should have its mimetype set to application/octet-stream" do
      expect(@format.mime).to eq("application/octet-stream")
    end

    it "should always be supported" do
      expect(@format).to be_supported(String)
    end

    it "should fail if its multiple_render method is used" do
      expect { @format.render_multiple("foo") }.to raise_error(NotImplementedError)
    end

    it "should fail if its multiple_intern method is used" do
      expect { @format.intern_multiple(String, "foo") }.to raise_error(NotImplementedError)
    end

    it "should have a weight of 1" do
      expect(@format.weight).to eq(1)
    end
  end

  it "should include a pson format" do
    expect(Puppet::Network::FormatHandler.format(:pson)).not_to be_nil
  end

  describe "pson" do
    before do
      @pson = Puppet::Network::FormatHandler.format(:pson)
    end

    it "should have its mime type set to text/pson" do
      expect(Puppet::Network::FormatHandler.format(:pson).mime).to eq("text/pson")
    end

    it "should require the :render_method" do
      expect(Puppet::Network::FormatHandler.format(:pson).required_methods).to be_include(:render_method)
    end

    it "should require the :intern_method" do
      expect(Puppet::Network::FormatHandler.format(:pson).required_methods).to be_include(:intern_method)
    end

    it "should have a weight of 10" do
      expect(@pson.weight).to eq(10)
    end

    describe "when supported" do
      it "should render by calling 'to_pson' on the instance" do
        instance = PsonTest.new("foo")
        instance.expects(:to_pson).returns "foo"
        expect(@pson.render(instance)).to eq("foo")
      end

      it "should render multiple instances by calling 'to_pson' on the array" do
        instances = [mock('instance')]

        instances.expects(:to_pson).returns "foo"

        expect(@pson.render_multiple(instances)).to eq("foo")
      end

      it "should intern by calling 'PSON.parse' on the text and then using from_data_hash to convert the data into an instance" do
        text = "foo"
        PSON.expects(:parse).with("foo").returns("type" => "PsonTest", "data" => "foo")
        PsonTest.expects(:from_data_hash).with("foo").returns "parsed_pson"
        expect(@pson.intern(PsonTest, text)).to eq("parsed_pson")
      end

      it "should not render twice if 'PSON.parse' creates the appropriate instance" do
        text = "foo"
        instance = PsonTest.new("foo")
        PSON.expects(:parse).with("foo").returns(instance)
        PsonTest.expects(:from_data_hash).never
        expect(@pson.intern(PsonTest, text)).to equal(instance)
      end

      it "should intern by calling 'PSON.parse' on the text and then using from_data_hash to convert the actual into an instance if the pson has no class/data separation" do
        text = "foo"
        PSON.expects(:parse).with("foo").returns("foo")
        PsonTest.expects(:from_data_hash).with("foo").returns "parsed_pson"
        expect(@pson.intern(PsonTest, text)).to eq("parsed_pson")
      end

      it "should intern multiples by parsing the text and using 'class.intern' on each resulting data structure" do
        text = "foo"
        PSON.expects(:parse).with("foo").returns ["bar", "baz"]
        PsonTest.expects(:from_data_hash).with("bar").returns "BAR"
        PsonTest.expects(:from_data_hash).with("baz").returns "BAZ"
        expect(@pson.intern_multiple(PsonTest, text)).to eq(%w{BAR BAZ})
      end

      it "fails intelligibly when given invalid data" do
        expect do
          @pson.intern(Puppet::Node, '')
        end.to raise_error(PSON::ParserError, /source did not contain any PSON/)
      end
    end
  end

  describe ":console format" do
    subject { Puppet::Network::FormatHandler.format(:console) }
    it { is_expected.to be_an_instance_of Puppet::Network::Format }
    let :json do Puppet::Network::FormatHandler.format(:pson) end

    [:intern, :intern_multiple].each do |method|
      it "should not implement #{method}" do
        expect { subject.send(method, String, 'blah') }.to raise_error NotImplementedError
      end
    end

    ["hello", 1, 1.0].each do |input|
      it "should just return a #{input.inspect}" do
        expect(subject.render(input)).to eq(input)
      end
    end

    [true, false, nil, Object.new].each do |input|
      it "renders #{input.class} using PSON" do
        expect(subject.render(input)).to eq(input.to_pson)
      end
    end

    [[1, 2], ["one"], [{ 1 => 1 }]].each do |input|
      it "should render #{input.inspect} as one item per line" do
        expect(subject.render(input)).to eq(input.collect { |item| item.to_s + "\n" }.join(''))
      end
    end

    it "should render empty hashes as empty strings" do
      expect(subject.render({})).to eq('')
    end

    it "should render a non-trivially-keyed Hash as pretty printed PSON" do
      hash = { [1,2] => 3, [2,3] => 5, [3,4] => 7 }
      expect(subject.render(hash)).to eq(PSON.pretty_generate(hash).chomp)
    end

    it "should render a {String,Numeric}-keyed Hash into a table" do
      object = Object.new
      hash = { "one" => 1, "two" => [], "three" => {}, "four" => object,
        5 => 5, 6.0 => 6 }

      # Gotta love ASCII-betical sort order.  Hope your objects are better
      # structured for display than my test one is. --daniel 2011-04-18
      expect(subject.render(hash)).to eq <<EOT
5      5
6.0    6
four   #{json.render(object).chomp}
one    1
three  {}
two    []
EOT
    end

    it "should render a hash nicely with a multi-line value" do
      pending "Moving to PSON rather than PP makes this unsupportable."
      hash = {
        "number" => { "1" => '1' * 40, "2" => '2' * 40, '3' => '3' * 40 },
        "text"   => { "a" => 'a' * 40, 'b' => 'b' * 40, 'c' => 'c' * 40 }
      }
      expect(subject.render(hash)).to eq <<EOT
number  {"1"=>"1111111111111111111111111111111111111111",
         "2"=>"2222222222222222222222222222222222222222",
         "3"=>"3333333333333333333333333333333333333333"}
text    {"a"=>"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
         "b"=>"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
         "c"=>"cccccccccccccccccccccccccccccccccccccccc"}
EOT
    end
  end
end
