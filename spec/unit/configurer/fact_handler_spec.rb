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

  it "should serialize and CGI escape the fact values for uploading" do
    facts = Puppet::Node::Facts.new(Puppet[:node_name_value], 'my_name_fact' => 'other_node_name')
    Puppet::Node::Facts.indirection.save(facts)
    text = CGI.escape(facthandler.find_facts.render(:pson))

    expect(facthandler.facts_for_uploading).to eq({:facts_format => :pson, :facts => text})
  end

  it "should properly accept facts containing a '+'" do
    facts = Puppet::Node::Facts.new('foo', 'afact' => 'a+b')
    Puppet::Node::Facts.indirection.save(facts)
    text = CGI.escape(facthandler.find_facts.render(:pson))

    expect(facthandler.facts_for_uploading).to eq({:facts_format => :pson, :facts => text})
  end

  it "should generate valid facts data against the facts schema" do
    facts = Puppet::Node::Facts.new(Puppet[:node_name_value], 'my_name_fact' => 'other_node_name')
    Puppet::Node::Facts.indirection.save(facts)

    expect(CGI.unescape(facthandler.facts_for_uploading[:facts])).to validate_against('api/schemas/facts.json')
  end

end

