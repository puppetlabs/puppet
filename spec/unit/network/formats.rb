#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/network/formats'

class PsonTest
    attr_accessor :string
    def ==(other)
        string == other.string
    end

    def self.from_pson(data)
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

        it "should fixup generated yaml on render" do
            instance = mock 'instance', :to_yaml => "foo"

            @yaml.expects(:fixup).with("foo").returns "bar"

            @yaml.render(instance).should == "bar"
        end

        it "should render multiple instances by calling 'to_yaml' on the array" do
            instances = [mock('instance')]
            instances.expects(:to_yaml).returns "foo"
            @yaml.render_multiple(instances).should == "foo"
        end

        it "should fixup generated yaml on render" do
            instances = [mock('instance')]
            instances.stubs(:to_yaml).returns "foo"

            @yaml.expects(:fixup).with("foo").returns "bar"

            @yaml.render(instances).should == "bar"
        end

        it "should intern by calling 'YAML.load'" do
            text = "foo"
            YAML.expects(:load).with("foo").returns "bar"
            @yaml.intern(String, text).should == "bar"
        end

        it "should intern multiples by calling 'YAML.load'" do
            text = "foo"
            YAML.expects(:load).with("foo").returns "bar"
            @yaml.intern_multiple(String, text).should == "bar"
        end

        it "should fixup incorrect yaml to correct" do
            @yaml.fixup("&id004 !ruby/object:Puppet::Relationship ?").should == "? &id004 !ruby/object:Puppet::Relationship"
        end
    end

    describe "base64 compressed yaml" do
        yaml = Puppet::Network::FormatHandler.format(:b64_zlib_yaml)
        confine "We must have zlib" => Puppet.features.zlib?

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

        it "should fixup generated yaml on render" do
            instance = mock 'instance', :to_yaml => "foo"

            @yaml.expects(:fixup).with("foo").returns "bar"

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

        it "should fixup generated yaml on render" do
            instances = [mock('instance')]
            instances.stubs(:to_yaml).returns "foo"

            @yaml.expects(:fixup).with("foo").returns "bar"

            @yaml.render(instances)
        end

        it "should encode generated yaml on render" do
            instances = [mock('instance')]
            instances.stubs(:to_yaml).returns "foo"

            @yaml.expects(:encode).with("foo").returns "bar"

            @yaml.render(instances).should == "bar"
        end

        it "should intern by calling decode" do
            text = "foo"
            @yaml.expects(:decode).with("foo").returns "bar"
            @yaml.intern(String, text).should == "bar"
        end

        it "should intern multiples by calling 'decode'" do
            text = "foo"
            @yaml.expects(:decode).with("foo").returns "bar"
            @yaml.intern_multiple(String, text).should == "bar"
        end

        it "should decode by base64 decoding, uncompressing and Yaml loading" do
            Base64.expects(:decode64).with("zorg").returns "foo"
            Zlib::Inflate.expects(:inflate).with("foo").returns "baz"
            YAML.expects(:load).with("baz").returns "bar"
            @yaml.decode("zorg").should == "bar"
        end

        it "should encode by compressing and base64 encoding" do
            Zlib::Deflate.expects(:deflate).with("foo", Zlib::BEST_COMPRESSION).returns "bar"
            Base64.expects(:encode64).with("bar").returns "baz"
            @yaml.encode("foo").should == "baz"
        end

        it "should fixup incorrect yaml to correct" do
            @yaml.fixup("&id004 !ruby/object:Puppet::Relationship ?").should == "? &id004 !ruby/object:Puppet::Relationship"
        end

        describe "when zlib is disabled" do
            before do
                Puppet[:zlib] = false
            end

            it "use_zlib? should return false" do
                @yaml.use_zlib?.should == false  
            end

            it "should refuse to encode" do
                lambda{ @yaml.encode("foo") }.should raise_error
            end

            it "should refuse to decode" do
                lambda{ @yaml.decode("foo") }.should raise_error
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

    it "should include a marshal format" do
        Puppet::Network::FormatHandler.format(:marshal).should_not be_nil
    end

    describe "marshal" do
        before do
            @marshal = Puppet::Network::FormatHandler.format(:marshal)
        end

        it "should have its mime type set to text/marshal" do
            Puppet::Network::FormatHandler.format(:marshal).mime.should == "text/marshal"
        end

        it "should be supported on Strings" do
            @marshal.should be_supported(String)
        end

        it "should render by calling 'Marshal.dump' on the instance" do
            instance = mock 'instance'
            Marshal.expects(:dump).with(instance).returns "foo"
            @marshal.render(instance).should == "foo"
        end

        it "should render multiple instances by calling 'to_marshal' on the array" do
            instances = [mock('instance')]

            Marshal.expects(:dump).with(instances).returns "foo"
            @marshal.render_multiple(instances).should == "foo"
        end

        it "should intern by calling 'Marshal.load'" do
            text = "foo"
            Marshal.expects(:load).with("foo").returns "bar"
            @marshal.intern(String, text).should == "bar"
        end

        it "should intern multiples by calling 'Marshal.load'" do
            text = "foo"
            Marshal.expects(:load).with("foo").returns "bar"
            @marshal.intern_multiple(String, text).should == "bar"
        end
    end

    describe "plaintext" do
        before do
            @text = Puppet::Network::FormatHandler.format(:s)
        end

        it "should have its mimetype set to text/plain" do
            @text.mime.should == "text/plain"
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
        confine "Missing 'pson' library" => Puppet.features.pson?

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

            it "should intern by calling 'PSON.parse' on the text and then using from_pson to convert the data into an instance" do
                text = "foo"
                PSON.expects(:parse).with("foo").returns("type" => "PsonTest", "data" => "foo")
                PsonTest.expects(:from_pson).with("foo").returns "parsed_pson"
                @pson.intern(PsonTest, text).should == "parsed_pson"
            end

            it "should not render twice if 'PSON.parse' creates the appropriate instance" do
                text = "foo"
                instance = PsonTest.new("foo")
                PSON.expects(:parse).with("foo").returns(instance)
                PsonTest.expects(:from_pson).never
                @pson.intern(PsonTest, text).should equal(instance)
            end

            it "should intern by calling 'PSON.parse' on the text and then using from_pson to convert the actual into an instance if the pson has no class/data separation" do
                text = "foo"
                PSON.expects(:parse).with("foo").returns("foo")
                PsonTest.expects(:from_pson).with("foo").returns "parsed_pson"
                @pson.intern(PsonTest, text).should == "parsed_pson"
            end

            it "should intern multiples by parsing the text and using 'class.intern' on each resulting data structure" do
                text = "foo"
                PSON.expects(:parse).with("foo").returns ["bar", "baz"]
                PsonTest.expects(:from_pson).with("bar").returns "BAR"
                PsonTest.expects(:from_pson).with("baz").returns "BAZ"
                @pson.intern_multiple(PsonTest, text).should == %w{BAR BAZ}
            end
        end
    end
end
