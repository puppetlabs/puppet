#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/network/formats'

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

        it "should render multiple instances by calling 'to_yaml' on the array" do
            instances = [mock('instance')]
            instances.expects(:to_yaml).returns "foo"
            @yaml.render_multiple(instances).should == "foo"
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

        it "should fail if the instance does not respond to 'to_s'" do
            instance = mock 'nope'
            instance.expects(:to_s).never
            lambda { @text.render(instance) }.should raise_error(NotImplementedError)
        end

        it "should render by calling 'to_s' on the instance" do
            # Use an instance that responds to 'to_s'
            instance = "foo"
            instance.expects(:to_s).returns "string"
            @text.render(instance).should == "string"
        end

        it "should render multiple instances by calling 'to_s' on each instance and joining the results with '\\n---\\n'" do
            instances = ["string1", 'string2']

            @text.render_multiple(instances).should == "string1\n---\nstring2"
        end

        it "should intern by calling 'from_s' on the class" do
            text = "foo"
            String.expects(:from_s).with(text).returns "bar"
            @text.intern(String, text).should == "bar"
        end

        it "should intern multiples by splitting on '\\n---\\n' and converting each string to an instance" do
            text = "foo\n---\nbar"
            String.expects(:from_s).with("foo").returns "FOO"
            String.expects(:from_s).with("bar").returns "BAR"
            @text.intern_multiple(String, text).should == ["FOO", "BAR"]
        end
    end
end
