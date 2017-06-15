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
      expect(format).to respond_to(:asdfghjkl)
    end
  end

  describe "when retrieving formats" do
    let!(:format) { Puppet::Network::FormatHandler.create(:the_format, :extension => "foo", :mime => "foo/bar") }

    it "should be able to retrieve a format by name" do
      expect(Puppet::Network::FormatHandler.format(:the_format)).to equal(format)
    end

    it "should be able to retrieve a format by extension" do
      expect(Puppet::Network::FormatHandler.format_by_extension("foo")).to equal(format)
    end

    it "should return nil if asked to return a format by an unknown extension" do
      expect(Puppet::Network::FormatHandler.format_by_extension("yayness")).to be_nil
    end

    it "should be able to retrieve formats by name irrespective of case" do
      expect(Puppet::Network::FormatHandler.format(:The_Format)).to equal(format)
    end

    it "should be able to retrieve a format by mime type" do
      expect(Puppet::Network::FormatHandler.mime("foo/bar")).to equal(format)
    end

    it "should be able to retrieve a format by mime type irrespective of case" do
      expect(Puppet::Network::FormatHandler.mime("Foo/Bar")).to equal(format)
    end
  end

  describe "#most_suitable_formats_for" do
    before :each do
      Puppet::Network::FormatHandler.create(:one, :extension => "foo", :mime => "text/one")
      Puppet::Network::FormatHandler.create(:two, :extension => "bar", :mime => "application/two")
    end

    let(:format_one) { Puppet::Network::FormatHandler.format(:one) }
    let(:format_two) { Puppet::Network::FormatHandler.format(:two) }

    def suitable_in_setup_formats(accepted)
      Puppet::Network::FormatHandler.most_suitable_formats_for(accepted, [:one, :two])
    end

    it "finds the most preferred format when anything is acceptable" do
      expect(Puppet::Network::FormatHandler.most_suitable_formats_for(["*/*"], [:two, :one])).to eq([format_two])
    end

    it "finds no format when none are acceptable" do
      expect(suitable_in_setup_formats(["three"])).to eq([])
    end

    it "returns only the accepted and supported format" do
      expect(suitable_in_setup_formats(["three", "two"])).to eq([format_two])
    end

    it "returns only accepted and supported formats, in order of accepted" do
      expect(suitable_in_setup_formats(["three", "two", "one"])).to eq([format_two, format_one])
    end

    it "allows specifying acceptable formats by mime type" do
      expect(suitable_in_setup_formats(["text/one"])).to eq([format_one])
    end

    it "ignores quality specifiers" do
      expect(suitable_in_setup_formats(["two;q=0.8", "text/one;q=0.9"])).to eq([format_two, format_one])
    end

    it "allows specifying acceptable formats by canonical name" do
      expect(suitable_in_setup_formats([:one])).to eq([format_one])
    end
  end
end
