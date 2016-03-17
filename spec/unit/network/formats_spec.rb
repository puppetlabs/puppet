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
    Puppet::Network::FormatHandler.format(:msgpack).should_not be_nil
  end

  describe "msgpack", :if => Puppet.features.msgpack? do
    before do
      @msgpack = Puppet::Network::FormatHandler.format(:msgpack)
    end

    it "should have its mime type set to application/x-msgpack" do
      @msgpack.mime.should == "application/x-msgpack"
    end

    it "should have a weight of 20" do
      @msgpack.weight.should == 20
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
      catunpack.should include(
        "tags"=>[],
        "name"=>"foo",
        "version"=>nil,
        "environment"=>"testing",
        "edges"=>[],
        "classes"=>[]
      )
      catunpack["resources"][0].should include(
        "type"=>"File",
        "title"=>"my_file",
        "exported"=>false
      )
      catunpack["resources"][0]["tags"].should include(
        "file",
        "my_file"
      )
    end
  end

  it "should include a yaml format" do
    Puppet::Network::FormatHandler.format(:yaml).should_not be_nil
  end

  describe "yaml" do
    before do
      @yaml = Puppet::Network::FormatHandler.format(:yaml)
    end

    it "should have its mime type set to text/yaml" do
      @yaml.mime.should == "text/yaml"
    end

    it "should be supported on Strings" do
      @yaml.should be_supported(String)
    end

    it "should render by calling 'to_yaml' on the instance" do
      instance = mock 'instance'
      instance.expects(:to_yaml).returns "foo"
      @yaml.render(instance).should == "foo"
    end

    it "should render multiple instances by calling 'to_yaml' on the array" do
      instances = [mock('instance')]
      instances.expects(:to_yaml).returns "foo"
      @yaml.render_multiple(instances).should == "foo"
    end

    it "should deserialize YAML" do
      @yaml.intern(String, YAML.dump("foo")).should == "foo"
    end

    it "should deserialize symbols as strings" do
      @yaml.intern(String, YAML.dump(:foo)).should == "foo"
    end

    it "should load from yaml when deserializing an array" do
      text = YAML.dump(["foo"])
      @yaml.intern_multiple(String, text).should == ["foo"]
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

  describe "base64 compressed yaml", :if => Puppet.features.zlib? do
    before do
      @yaml = Puppet::Network::FormatHandler.format(:b64_zlib_yaml)
    end

    it "should have its mime type set to text/b64_zlib_yaml" do
      @yaml.mime.should == "text/b64_zlib_yaml"
    end

    it "should render by calling 'to_yaml' on the instance" do
      instance = mock 'instance'
      instance.expects(:to_yaml).returns "foo"
      @yaml.render(instance)
    end

    it "should encode generated yaml on render" do
      instance = mock 'instance', :to_yaml => "foo"

      @yaml.expects(:encode).with("foo").returns "bar"

      @yaml.render(instance).should == "bar"
    end

    it "should render multiple instances by calling 'to_yaml' on the array" do
      instances = [mock('instance')]
      instances.expects(:to_yaml).returns "foo"
      @yaml.render_multiple(instances)
    end

    it "should encode generated yaml on render" do
      instances = [mock('instance')]
      instances.stubs(:to_yaml).returns "foo"

      @yaml.expects(:encode).with("foo").returns "bar"

      @yaml.render(instances).should == "bar"
    end

    it "should round trip data" do
      @yaml.intern(String, @yaml.encode("foo")).should == "foo"
    end

    it "should round trip multiple data elements" do
      data = @yaml.render_multiple(["foo", "bar"])
      @yaml.intern_multiple(String, data).should == ["foo", "bar"]
    end

    it "should intern by base64 decoding, uncompressing and safely Yaml loading" do
      input = Base64.encode64(Zlib::Deflate.deflate(YAML.dump("data in")))

      @yaml.intern(String, input).should == "data in"
    end

    it "should render by compressing and base64 encoding" do
      output = @yaml.render("foo")

      YAML.load(Zlib::Inflate.inflate(Base64.decode64(output))).should == "foo"
    end

    describe "when zlib is disabled" do
      before do
        Puppet[:zlib] = false
      end

      it "use_zlib? should return false" do
        @yaml.use_zlib?.should == false
      end

      it "should refuse to encode" do
        expect { @yaml.render("foo") }.to raise_error(Puppet::Error, /zlib library is not installed/)
      end

      it "should refuse to decode" do
        expect { @yaml.intern(String, "foo") }.to raise_error(Puppet::Error, /zlib library is not installed/)
      end
    end

    describe "when zlib is not installed" do
      it "use_zlib? should return false" do
        Puppet[:zlib] = true
        Puppet.features.expects(:zlib?).returns(false)

        @yaml.use_zlib?.should == false
      end
    end

  end

  describe "plaintext" do
    before do
      @text = Puppet::Network::FormatHandler.format(:s)
    end

    it "should have its mimetype set to text/plain" do
      @text.mime.should == "text/plain"
    end

    it "should use 'txt' as its extension" do
      @text.extension.should == "txt"
    end
  end

  describe "dot" do
    before do
      @dot = Puppet::Network::FormatHandler.format(:dot)
    end

    it "should have its mimetype set to text/dot" do
      @dot.mime.should == "text/dot"
    end
  end

  describe Puppet::Network::FormatHandler.format(:raw) do
    before do
      @format = Puppet::Network::FormatHandler.format(:raw)
    end

    it "should exist" do
      @format.should_not be_nil
    end

    it "should have its mimetype set to application/x-raw" do
      @format.mime.should == "application/x-raw"
    end

    it "should always be supported" do
      @format.should be_supported(String)
    end

    it "should fail if its multiple_render method is used" do
      lambda { @format.render_multiple("foo") }.should raise_error(NotImplementedError)
    end

    it "should fail if its multiple_intern method is used" do
      lambda { @format.intern_multiple(String, "foo") }.should raise_error(NotImplementedError)
    end

    it "should have a weight of 1" do
      @format.weight.should == 1
    end
  end

  it "should include a pson format" do
    Puppet::Network::FormatHandler.format(:pson).should_not be_nil
  end

  describe "pson" do
    before do
      @pson = Puppet::Network::FormatHandler.format(:pson)
    end

    it "should have its mime type set to text/pson" do
      Puppet::Network::FormatHandler.format(:pson).mime.should == "text/pson"
    end

    it "should require the :render_method" do
      Puppet::Network::FormatHandler.format(:pson).required_methods.should be_include(:render_method)
    end

    it "should require the :intern_method" do
      Puppet::Network::FormatHandler.format(:pson).required_methods.should be_include(:intern_method)
    end

    it "should have a weight of 10" do
      @pson.weight.should == 10
    end

    describe "when supported" do
      it "should render by calling 'to_pson' on the instance" do
        instance = PsonTest.new("foo")
        instance.expects(:to_pson).returns "foo"
        @pson.render(instance).should == "foo"
      end

      it "should render multiple instances by calling 'to_pson' on the array" do
        instances = [mock('instance')]

        instances.expects(:to_pson).returns "foo"

        @pson.render_multiple(instances).should == "foo"
      end

      it "should intern by calling 'PSON.parse' on the text and then using from_data_hash to convert the data into an instance" do
        text = "foo"
        PSON.expects(:parse).with("foo").returns("type" => "PsonTest", "data" => "foo")
        PsonTest.expects(:from_data_hash).with("foo").returns "parsed_pson"
        @pson.intern(PsonTest, text).should == "parsed_pson"
      end

      it "should not render twice if 'PSON.parse' creates the appropriate instance" do
        text = "foo"
        instance = PsonTest.new("foo")
        PSON.expects(:parse).with("foo").returns(instance)
        PsonTest.expects(:from_data_hash).never
        @pson.intern(PsonTest, text).should equal(instance)
      end

      it "should intern by calling 'PSON.parse' on the text and then using from_data_hash to convert the actual into an instance if the pson has no class/data separation" do
        text = "foo"
        PSON.expects(:parse).with("foo").returns("foo")
        PsonTest.expects(:from_data_hash).with("foo").returns "parsed_pson"
        @pson.intern(PsonTest, text).should == "parsed_pson"
      end

      it "should intern multiples by parsing the text and using 'class.intern' on each resulting data structure" do
        text = "foo"
        PSON.expects(:parse).with("foo").returns ["bar", "baz"]
        PsonTest.expects(:from_data_hash).with("bar").returns "BAR"
        PsonTest.expects(:from_data_hash).with("baz").returns "BAZ"
        @pson.intern_multiple(PsonTest, text).should == %w{BAR BAZ}
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
    it { should be_an_instance_of Puppet::Network::Format }
    let :json do Puppet::Network::FormatHandler.format(:pson) end

    [:intern, :intern_multiple].each do |method|
      it "should not implement #{method}" do
        expect { subject.send(method, String, 'blah') }.to raise_error NotImplementedError
      end
    end

    ["hello", 1, 1.0].each do |input|
      it "should just return a #{input.inspect}" do
        subject.render(input).should == input
      end
    end

    [[1, 2], ["one"], [{ 1 => 1 }]].each do |input|
      it "should render #{input.inspect} as one item per line" do
        subject.render(input).should == input.collect { |item| item.to_s + "\n" }.join('')
      end
    end

    it "should render empty hashes as empty strings" do
      subject.render({}).should == ''
    end

    it "should render a non-trivially-keyed Hash as JSON" do
      hash = { [1,2] => 3, [2,3] => 5, [3,4] => 7 }
      subject.render(hash).should == json.render(hash).chomp
    end

    it "should render a {String,Numeric}-keyed Hash into a table" do
      object = Object.new
      hash = { "one" => 1, "two" => [], "three" => {}, "four" => object,
        5 => 5, 6.0 => 6 }

      # Gotta love ASCII-betical sort order.  Hope your objects are better
      # structured for display than my test one is. --daniel 2011-04-18
      subject.render(hash).should == <<EOT
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
      subject.render(hash).should == <<EOT
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
