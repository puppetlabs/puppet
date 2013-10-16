#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/network/format_handler'

describe Puppet::Network::FormatHandler do
  before(:each) do
    @saved_formats = Puppet::Network::FormatHandler.instance_variable_get(:@formats).dup
    Puppet::Network::FormatHandler.instance_variable_set(:@formats, {})
  end

  after(:each) do
    Puppet::Network::FormatHandler.instance_variable_set(:@formats, @saved_formats)
  end

  describe "when creating formats" do
    it "should instance_eval any block provided when creating a format" do
      format = Puppet::Network::FormatHandler.create(:test_format) do
        def asdfghjkl; end
      end
      format.should respond_to(:asdfghjkl)
    end
  end

  describe "when retrieving formats" do
    let!(:format) { Puppet::Network::FormatHandler.create(:the_format, :extension => "foo", :mime => "foo/bar") }

    it "should be able to retrieve a format by name" do
      Puppet::Network::FormatHandler.format(:the_format).should equal(format)
    end

    it "should be able to retrieve a format by extension" do
      Puppet::Network::FormatHandler.format_by_extension("foo").should equal(format)
    end

    it "should return nil if asked to return a format by an unknown extension" do
      Puppet::Network::FormatHandler.format_by_extension("yayness").should be_nil
    end

    it "should be able to retrieve formats by name irrespective of case" do
      Puppet::Network::FormatHandler.format(:The_Format).should equal(format)
    end

    it "should be able to retrieve a format by mime type" do
      Puppet::Network::FormatHandler.mime("foo/bar").should equal(format)
    end

    it "should be able to retrieve a format by mime type irrespective of case" do
      Puppet::Network::FormatHandler.mime("Foo/Bar").should equal(format)
    end
  end

  describe "#most_suitable_format_for" do
    before :each do
      Puppet::Network::FormatHandler.create(:one, :extension => "foo", :mime => "text/one")
      Puppet::Network::FormatHandler.create(:two, :extension => "bar", :mime => "application/two")
    end

    let(:format_one) { Puppet::Network::FormatHandler.format(:one) }
    let(:format_two) { Puppet::Network::FormatHandler.format(:two) }

    def suitable_in_setup_formats(accepted)
      Puppet::Network::FormatHandler.most_suitable_format_for(accepted, [:one, :two])
    end

    it "finds the most preferred format when anything is acceptable" do
      Puppet::Network::FormatHandler.most_suitable_format_for(["*/*"], [:two, :one]).should == format_two
    end

    it "finds no format when none are acceptable" do
      suitable_in_setup_formats(["three"]).should be_nil
    end

    it "skips unsupported, but accepted, formats" do
      suitable_in_setup_formats(["three", "two"]).should == format_two
    end

    it "gives the first acceptable and suitable format" do
      suitable_in_setup_formats(["three", "one", "two"]).should == format_one
    end

    it "allows specifying acceptable formats by mime type" do
      suitable_in_setup_formats(["text/one"]).should == format_one
    end

    it "ignores quality specifiers" do
      suitable_in_setup_formats(["two;q=0.8", "text/one;q=0.9"]).should == format_two
    end

    it "allows specifying acceptable formats by canonical name" do
      suitable_in_setup_formats([:one]).should == format_one
    end
  end
end
