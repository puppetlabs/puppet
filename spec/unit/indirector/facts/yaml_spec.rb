#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/node/facts'
require 'puppet/indirector/facts/yaml'

describe Puppet::Node::Facts::Yaml do
  it "should be a subclass of the Yaml terminus" do
    expect(Puppet::Node::Facts::Yaml.superclass).to equal(Puppet::Indirector::Yaml)
  end

  it "should have documentation" do
    expect(Puppet::Node::Facts::Yaml.doc).not_to be_nil
    expect(Puppet::Node::Facts::Yaml.doc).not_to be_empty
  end

  it "should be registered with the facts indirection" do
    indirection = Puppet::Indirector::Indirection.instance(:facts)
    expect(Puppet::Node::Facts::Yaml.indirection).to equal(indirection)
  end

  it "should have its name set to :yaml" do
    expect(Puppet::Node::Facts::Yaml.name).to eq(:yaml)
  end

  it "should allow network requests" do
    # Doesn't allow yaml as a network format, but allows `puppet facts upload`
    # to update the YAML cache on a master.
    expect(Puppet::Node::Facts::Yaml.new.allow_remote_requests?).to be(true)
  end

  describe "#search" do
    def assert_search_matches(matching, nonmatching, query)
      request = Puppet::Indirector::Request.new(:inventory, :search, nil, nil, query)

      Dir.stubs(:glob).returns(matching.keys + nonmatching.keys)
      [matching, nonmatching].each do |examples|
        examples.each do |key, value|
          YAML.stubs(:load_file).with(key).returns value
        end
      end
      expect(Puppet::Node::Facts::Yaml.new.search(request)).to match_array(matching.values.map {|facts| facts.name})
    end

    it "should return node names that match the search query options" do
      assert_search_matches({
          '/path/to/matching.yaml'  => Puppet::Node::Facts.new("matchingnode",  "architecture" => "i386", 'processor_count' => '4'),
          '/path/to/matching1.yaml' => Puppet::Node::Facts.new("matchingnode1", "architecture" => "i386", 'processor_count' => '4', 'randomfact' => 'foo')
        },
        {
          "/path/to/nonmatching.yaml"  => Puppet::Node::Facts.new("nonmatchingnode",  "architecture" => "powerpc", 'processor_count' => '4'),
          "/path/to/nonmatching1.yaml" => Puppet::Node::Facts.new("nonmatchingnode1", "architecture" => "powerpc", 'processor_count' => '5'),
          "/path/to/nonmatching2.yaml" => Puppet::Node::Facts.new("nonmatchingnode2", "architecture" => "i386",    'processor_count' => '5'),
          "/path/to/nonmatching3.yaml" => Puppet::Node::Facts.new("nonmatchingnode3",                              'processor_count' => '4'),
        },
        {'facts.architecture' => 'i386', 'facts.processor_count' => '4'}
      )
    end

    it "should return empty array when no nodes match the search query options" do
      assert_search_matches({}, {
          "/path/to/nonmatching.yaml"  => Puppet::Node::Facts.new("nonmatchingnode",  "architecture" => "powerpc", 'processor_count' => '10'),
          "/path/to/nonmatching1.yaml" => Puppet::Node::Facts.new("nonmatchingnode1", "architecture" => "powerpc", 'processor_count' => '5'),
          "/path/to/nonmatching2.yaml" => Puppet::Node::Facts.new("nonmatchingnode2", "architecture" => "i386",    'processor_count' => '5'),
          "/path/to/nonmatching3.yaml" => Puppet::Node::Facts.new("nonmatchingnode3",                              'processor_count' => '4'),
        },
        {'facts.processor_count.lt' => '4', 'facts.processor_count.gt' => '4'}
      )
    end


    it "should return node names that match the search query options with the greater than operator" do
      assert_search_matches({
          '/path/to/matching.yaml'  => Puppet::Node::Facts.new("matchingnode",  "architecture" => "i386",    'processor_count' => '5'),
          '/path/to/matching1.yaml' => Puppet::Node::Facts.new("matchingnode1", "architecture" => "powerpc", 'processor_count' => '10', 'randomfact' => 'foo')
        },
        {
          "/path/to/nonmatching.yaml"  => Puppet::Node::Facts.new("nonmatchingnode",  "architecture" => "powerpc", 'processor_count' => '4'),
          "/path/to/nonmatching2.yaml" => Puppet::Node::Facts.new("nonmatchingnode2", "architecture" => "i386",    'processor_count' => '3'),
          "/path/to/nonmatching3.yaml" => Puppet::Node::Facts.new("nonmatchingnode3"                                                       ),
        },
        {'facts.processor_count.gt' => '4'}
      )
    end

    it "should return node names that match the search query options with the less than operator" do
      assert_search_matches({
          '/path/to/matching.yaml'  => Puppet::Node::Facts.new("matchingnode",  "architecture" => "i386",    'processor_count' => '5'),
          '/path/to/matching1.yaml' => Puppet::Node::Facts.new("matchingnode1", "architecture" => "powerpc", 'processor_count' => '30', 'randomfact' => 'foo')
        },
        {
          "/path/to/nonmatching.yaml"  => Puppet::Node::Facts.new("nonmatchingnode",  "architecture" => "powerpc", 'processor_count' => '50' ),
          "/path/to/nonmatching2.yaml" => Puppet::Node::Facts.new("nonmatchingnode2", "architecture" => "i386",    'processor_count' => '100'),
          "/path/to/nonmatching3.yaml" => Puppet::Node::Facts.new("nonmatchingnode3"                                                         ),
        },
        {'facts.processor_count.lt' => '50'}
      )
    end

    it "should return node names that match the search query options with the less than or equal to operator" do
      assert_search_matches({
          '/path/to/matching.yaml'  => Puppet::Node::Facts.new("matchingnode",  "architecture" => "i386",    'processor_count' => '5'),
          '/path/to/matching1.yaml' => Puppet::Node::Facts.new("matchingnode1", "architecture" => "powerpc", 'processor_count' => '50', 'randomfact' => 'foo')
        },
        {
          "/path/to/nonmatching.yaml"  => Puppet::Node::Facts.new("nonmatchingnode",  "architecture" => "powerpc", 'processor_count' => '100' ),
          "/path/to/nonmatching2.yaml" => Puppet::Node::Facts.new("nonmatchingnode2", "architecture" => "i386",    'processor_count' => '5000'),
          "/path/to/nonmatching3.yaml" => Puppet::Node::Facts.new("nonmatchingnode3"                                                          ),
        },
        {'facts.processor_count.le' => '50'}
      )
    end

    it "should return node names that match the search query options with the greater than or equal to operator" do
      assert_search_matches({
          '/path/to/matching.yaml'  => Puppet::Node::Facts.new("matchingnode",  "architecture" => "i386",    'processor_count' => '100'),
          '/path/to/matching1.yaml' => Puppet::Node::Facts.new("matchingnode1", "architecture" => "powerpc", 'processor_count' => '50', 'randomfact' => 'foo')
        },
        {
          "/path/to/nonmatching.yaml"  => Puppet::Node::Facts.new("nonmatchingnode",  "architecture" => "powerpc", 'processor_count' => '40'),
          "/path/to/nonmatching2.yaml" => Puppet::Node::Facts.new("nonmatchingnode2", "architecture" => "i386",    'processor_count' => '9' ),
          "/path/to/nonmatching3.yaml" => Puppet::Node::Facts.new("nonmatchingnode3"                                                        ),
        },
        {'facts.processor_count.ge' => '50'}
      )
    end

    it "should return node names that match the search query options with the not equal operator" do
      assert_search_matches({
          '/path/to/matching.yaml'  => Puppet::Node::Facts.new("matchingnode",  "architecture" => 'arm'                           ),
          '/path/to/matching1.yaml' => Puppet::Node::Facts.new("matchingnode1", "architecture" => 'powerpc', 'randomfact' => 'foo')
        },
        {
          "/path/to/nonmatching.yaml"  => Puppet::Node::Facts.new("nonmatchingnode",  "architecture" => "i386"                           ),
          "/path/to/nonmatching2.yaml" => Puppet::Node::Facts.new("nonmatchingnode2", "architecture" => "i386", 'processor_count' => '9' ),
          "/path/to/nonmatching3.yaml" => Puppet::Node::Facts.new("nonmatchingnode3"                                                     ),
        },
        {'facts.architecture.ne' => 'i386'}
      )
    end

    def apply_timestamp(facts, timestamp)
      facts.timestamp = timestamp
      facts
    end

    it "should be able to query based on meta.timestamp.gt" do
      assert_search_matches({
          '/path/to/2010-11-01.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-11-01", {}), Time.parse("2010-11-01")),
          '/path/to/2010-11-10.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-11-10", {}), Time.parse("2010-11-10")),
        },
        {
          '/path/to/2010-10-01.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-01", {}), Time.parse("2010-10-01")),
          '/path/to/2010-10-10.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-10", {}), Time.parse("2010-10-10")),
          '/path/to/2010-10-15.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-15", {}), Time.parse("2010-10-15")),
        },
        {'meta.timestamp.gt' => '2010-10-15'}
      )
    end

    it "should be able to query based on meta.timestamp.le" do
      assert_search_matches({
          '/path/to/2010-10-01.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-01", {}), Time.parse("2010-10-01")),
          '/path/to/2010-10-10.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-10", {}), Time.parse("2010-10-10")),
          '/path/to/2010-10-15.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-15", {}), Time.parse("2010-10-15")),
        },
        {
          '/path/to/2010-11-01.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-11-01", {}), Time.parse("2010-11-01")),
          '/path/to/2010-11-10.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-11-10", {}), Time.parse("2010-11-10")),
        },
        {'meta.timestamp.le' => '2010-10-15'}
      )
    end

    it "should be able to query based on meta.timestamp.lt" do
      assert_search_matches({
          '/path/to/2010-10-01.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-01", {}), Time.parse("2010-10-01")),
          '/path/to/2010-10-10.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-10", {}), Time.parse("2010-10-10")),
        },
        {
          '/path/to/2010-11-01.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-11-01", {}), Time.parse("2010-11-01")),
          '/path/to/2010-11-10.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-11-10", {}), Time.parse("2010-11-10")),
          '/path/to/2010-10-15.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-15", {}), Time.parse("2010-10-15")),
        },
        {'meta.timestamp.lt' => '2010-10-15'}
      )
    end

    it "should be able to query based on meta.timestamp.ge" do
      assert_search_matches({
          '/path/to/2010-11-01.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-11-01", {}), Time.parse("2010-11-01")),
          '/path/to/2010-11-10.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-11-10", {}), Time.parse("2010-11-10")),
          '/path/to/2010-10-15.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-15", {}), Time.parse("2010-10-15")),
        },
        {
          '/path/to/2010-10-01.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-01", {}), Time.parse("2010-10-01")),
          '/path/to/2010-10-10.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-10", {}), Time.parse("2010-10-10")),
        },
        {'meta.timestamp.ge' => '2010-10-15'}
      )
    end

    it "should be able to query based on meta.timestamp.eq" do
      assert_search_matches({
          '/path/to/2010-10-15.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-15", {}), Time.parse("2010-10-15")),
        },
        {
          '/path/to/2010-11-01.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-11-01", {}), Time.parse("2010-11-01")),
          '/path/to/2010-11-10.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-11-10", {}), Time.parse("2010-11-10")),
          '/path/to/2010-10-01.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-01", {}), Time.parse("2010-10-01")),
          '/path/to/2010-10-10.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-10", {}), Time.parse("2010-10-10")),
        },
        {'meta.timestamp.eq' => '2010-10-15'}
      )
    end

    it "should be able to query based on meta.timestamp" do
      assert_search_matches({
          '/path/to/2010-10-15.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-15", {}), Time.parse("2010-10-15")),
        },
        {
          '/path/to/2010-11-01.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-11-01", {}), Time.parse("2010-11-01")),
          '/path/to/2010-11-10.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-11-10", {}), Time.parse("2010-11-10")),
          '/path/to/2010-10-01.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-01", {}), Time.parse("2010-10-01")),
          '/path/to/2010-10-10.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-10", {}), Time.parse("2010-10-10")),
        },
        {'meta.timestamp' => '2010-10-15'}
      )
    end

    it "should be able to query based on meta.timestamp.ne" do
      assert_search_matches({
          '/path/to/2010-11-01.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-11-01", {}), Time.parse("2010-11-01")),
          '/path/to/2010-11-10.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-11-10", {}), Time.parse("2010-11-10")),
          '/path/to/2010-10-01.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-01", {}), Time.parse("2010-10-01")),
          '/path/to/2010-10-10.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-10", {}), Time.parse("2010-10-10")),
        },
        {
          '/path/to/2010-10-15.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-15", {}), Time.parse("2010-10-15")),
        },
        {'meta.timestamp.ne' => '2010-10-15'}
      )
    end
  end
end
