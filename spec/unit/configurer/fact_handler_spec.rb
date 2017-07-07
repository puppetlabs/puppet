#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/configurer'
require 'puppet/configurer/fact_handler'
require 'matchers/json'

class FactHandlerTester
  include Puppet::Configurer::FactHandler

  attr_accessor :environment

  def initialize(environment)
    self.environment = environment
  end

  def reload_facter
    # don't want to do this in tests
  end
end

describe Puppet::Configurer::FactHandler do
  include JSONMatchers

  let(:facthandler) { FactHandlerTester.new('production') }

  before :each do
    Puppet::Node::Facts.indirection.terminus_class = :memory
  end

  describe "when finding facts" do
    it "should use the node name value to retrieve the facts" do
      foo_facts = Puppet::Node::Facts.new('foo')
      bar_facts = Puppet::Node::Facts.new('bar')
      Puppet::Node::Facts.indirection.save(foo_facts)
      Puppet::Node::Facts.indirection.save(bar_facts)
      Puppet[:certname] = 'foo'
      Puppet[:node_name_value] = 'bar'

      expect(facthandler.find_facts).to eq(bar_facts)
    end

    it "should set the facts name based on the node_name_fact" do
      facts = Puppet::Node::Facts.new(Puppet[:node_name_value], 'my_name_fact' => 'other_node_name')
      Puppet::Node::Facts.indirection.save(facts)
      Puppet[:node_name_fact] = 'my_name_fact'

      expect(facthandler.find_facts.name).to eq('other_node_name')
    end

    it "should set the node_name_value based on the node_name_fact" do
      facts = Puppet::Node::Facts.new(Puppet[:node_name_value], 'my_name_fact' => 'other_node_name')
      Puppet::Node::Facts.indirection.save(facts)
      Puppet[:node_name_fact] = 'my_name_fact'

      facthandler.find_facts

      expect(Puppet[:node_name_value]).to eq('other_node_name')
    end

    it "should fail if finding facts fails" do
      Puppet::Node::Facts.indirection.expects(:find).raises RuntimeError

      expect { facthandler.find_facts }.to raise_error(Puppet::Error, /Could not retrieve local facts/)
    end

    it "should only load fact plugins once" do
      Puppet::Node::Facts.indirection.expects(:find).once
      facthandler.find_facts
    end
  end

  context "when serializing" do
    facts_with_special_characters = [
      { :hash => { 'afact' => 'a+b' }, :encoded => '%22values%22%3A%7B%22afact%22%3A%22' + 'a%2Bb' + '%22%7D' },
      { :hash => { 'afact' => 'a b' }, :encoded => '%22values%22%3A%7B%22afact%22%3A%22' + 'a%20b' + '%22%7D' },
      { :hash => { 'afact' => 'a&b' }, :encoded => '%22values%22%3A%7B%22afact%22%3A%22' + 'a%26b' + '%22%7D' },
      { :hash => { 'afact' => 'a*b' }, :encoded => '%22values%22%3A%7B%22afact%22%3A%22' + 'a%2Ab' + '%22%7D' },
      { :hash => { 'afact' => 'a=b' }, :encoded => '%22values%22%3A%7B%22afact%22%3A%22' + 'a%3Db' + '%22%7D' },
      # different UTF-8 widths
      # 1-byte A
      # 2-byte ۿ - http://www.fileformat.info/info/unicode/char/06ff/index.htm - 0xDB 0xBF / 219 191
      # 3-byte ᚠ - http://www.fileformat.info/info/unicode/char/16A0/index.htm - 0xE1 0x9A 0xA0 / 225 154 160
      # 4-byte 𠜎 - http://www.fileformat.info/info/unicode/char/2070E/index.htm - 0xF0 0xA0 0x9C 0x8E / 240 160 156 142
      { :hash => { 'afact' => "A\u06FF\u16A0\u{2070E}" }, :encoded => '%22values%22%3A%7B%22afact%22%3A%22' + 'A%DB%BF%E1%9A%A0%F0%A0%9C%8E' + '%22%7D' },
    ]

    context "as pson" do
      before :each do
        Puppet[:preferred_serialization_format] = 'pson'
      end

      it "should serialize and CGI escape the fact values for uploading" do
        facts = Puppet::Node::Facts.new(Puppet[:node_name_value], 'my_name_fact' => 'other_node_name')
        Puppet::Node::Facts.indirection.save(facts)
        text = Puppet::Util.uri_query_encode(facthandler.find_facts.render(:pson))

        expect(text).to include('%22values%22%3A%7B%22my_name_fact%22%3A%22other_node_name%22%7D')
        expect(facthandler.facts_for_uploading).to eq({:facts_format => :pson, :facts => text})
      end

      facts_with_special_characters.each do |test_fact|
        it "should properly accept the fact #{test_fact[:hash]}" do
          facts = Puppet::Node::Facts.new(Puppet[:node_name_value], test_fact[:hash])
          Puppet::Node::Facts.indirection.save(facts)
          text = Puppet::Util.uri_query_encode(facthandler.find_facts.render(:pson))

          to_upload = facthandler.facts_for_uploading
          expect(to_upload).to eq({:facts_format => :pson, :facts => text})
          expect(text).to include(test_fact[:encoded])

          # this is not sufficient to test whether these values are sent via HTTP GET or HTTP POST in actual catalog request
          expect(JSON.parse(URI.unescape(to_upload[:facts]))['values']).to eq(test_fact[:hash])
        end
      end
    end

    context "as json" do
      it "should serialize and CGI escape the fact values for uploading" do
        facts = Puppet::Node::Facts.new(Puppet[:node_name_value], 'my_name_fact' => 'other_node_name')
        Puppet::Node::Facts.indirection.save(facts)
        text = Puppet::Util.uri_query_encode(facthandler.find_facts.render(:json))

        expect(text).to include('%22values%22%3A%7B%22my_name_fact%22%3A%22other_node_name%22%7D')
        expect(facthandler.facts_for_uploading).to eq({:facts_format => 'application/json', :facts => text})
      end

      facts_with_special_characters.each do |test_fact|
        it "should properly accept the fact #{test_fact[:hash]}" do
          facts = Puppet::Node::Facts.new(Puppet[:node_name_value], test_fact[:hash])
          Puppet::Node::Facts.indirection.save(facts)
          text = Puppet::Util.uri_query_encode(facthandler.find_facts.render(:json))

          to_upload = facthandler.facts_for_uploading
          expect(to_upload).to eq({:facts_format => 'application/json', :facts => text})
          expect(text).to include(test_fact[:encoded])

          expect(JSON.parse(URI.unescape(to_upload[:facts]))['values']).to eq(test_fact[:hash])
        end
      end
    end

    it "should generate valid facts data against the facts schema" do
      facts = Puppet::Node::Facts.new(Puppet[:node_name_value], 'my_name_fact' => 'other_node_name')
      Puppet::Node::Facts.indirection.save(facts)

      # prefer URI.unescape but validate CGI also works
      encoded_facts = facthandler.facts_for_uploading[:facts]
      expect(URI.unescape(encoded_facts)).to validate_against('api/schemas/facts.json')
      expect(CGI.unescape(encoded_facts)).to validate_against('api/schemas/facts.json')
    end
  end
end
