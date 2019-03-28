require 'spec_helper'

require 'puppet/node/facts'
require 'puppet/indirector/facts/yaml'

def dir_containing_facts(hash)
  yamldir = tmpdir('yaml_facts')

  Puppet[:clientyamldir] = yamldir
  dir = File.join(yamldir, 'facts')
  Dir.mkdir(dir)
  hash.each_pair do |file, facts|
    File.open(File.join(dir, file), 'wb') do |f|
      f.write(YAML.dump(facts))
    end
  end
end

describe Puppet::Node::Facts::Yaml do
  include PuppetSpec::Files

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

      dir_containing_facts(matching.merge(nonmatching))

      results = Puppet::Node::Facts::Yaml.new.search(request)
      expect(results).to match_array(matching.values.map {|facts| facts.name})
    end

    it "should return node names that match the search query options" do
      assert_search_matches({
          'matching.yaml'  => Puppet::Node::Facts.new("matchingnode",  "architecture" => "i386", 'processor_count' => '4'),
          'matching1.yaml' => Puppet::Node::Facts.new("matchingnode1", "architecture" => "i386", 'processor_count' => '4', 'randomfact' => 'foo')
        },
        {
          "nonmatching.yaml"  => Puppet::Node::Facts.new("nonmatchingnode",  "architecture" => "powerpc", 'processor_count' => '4'),
          "nonmatching1.yaml" => Puppet::Node::Facts.new("nonmatchingnode1", "architecture" => "powerpc", 'processor_count' => '5'),
          "nonmatching2.yaml" => Puppet::Node::Facts.new("nonmatchingnode2", "architecture" => "i386",    'processor_count' => '5'),
          "nonmatching3.yaml" => Puppet::Node::Facts.new("nonmatchingnode3",                              'processor_count' => '4'),
        },
        {'facts.architecture' => 'i386', 'facts.processor_count' => '4'}
      )
    end

    it "should return empty array when no nodes match the search query options" do
      assert_search_matches({}, {
          "nonmatching.yaml"  => Puppet::Node::Facts.new("nonmatchingnode",  "architecture" => "powerpc", 'processor_count' => '10'),
          "nonmatching1.yaml" => Puppet::Node::Facts.new("nonmatchingnode1", "architecture" => "powerpc", 'processor_count' => '5'),
          "nonmatching2.yaml" => Puppet::Node::Facts.new("nonmatchingnode2", "architecture" => "i386",    'processor_count' => '5'),
          "nonmatching3.yaml" => Puppet::Node::Facts.new("nonmatchingnode3",                              'processor_count' => '4'),
        },
        {'facts.processor_count.lt' => '4', 'facts.processor_count.gt' => '4'}
      )
    end

    it "should return node names that match the search query options with the greater than operator" do
      assert_search_matches({
          'matching.yaml'  => Puppet::Node::Facts.new("matchingnode",  "architecture" => "i386",    'processor_count' => '5'),
          'matching1.yaml' => Puppet::Node::Facts.new("matchingnode1", "architecture" => "powerpc", 'processor_count' => '10', 'randomfact' => 'foo')
        },
        {
          "nonmatching.yaml"  => Puppet::Node::Facts.new("nonmatchingnode",  "architecture" => "powerpc", 'processor_count' => '4'),
          "nonmatching2.yaml" => Puppet::Node::Facts.new("nonmatchingnode2", "architecture" => "i386",    'processor_count' => '3'),
          "nonmatching3.yaml" => Puppet::Node::Facts.new("nonmatchingnode3"                                                       ),
        },
        {'facts.processor_count.gt' => '4'}
      )
    end

    it "should return node names that match the search query options with the less than operator" do
      assert_search_matches({
          'matching.yaml'  => Puppet::Node::Facts.new("matchingnode",  "architecture" => "i386",    'processor_count' => '5'),
          'matching1.yaml' => Puppet::Node::Facts.new("matchingnode1", "architecture" => "powerpc", 'processor_count' => '30', 'randomfact' => 'foo')
        },
        {
          "nonmatching.yaml"  => Puppet::Node::Facts.new("nonmatchingnode",  "architecture" => "powerpc", 'processor_count' => '50' ),
          "nonmatching2.yaml" => Puppet::Node::Facts.new("nonmatchingnode2", "architecture" => "i386",    'processor_count' => '100'),
          "nonmatching3.yaml" => Puppet::Node::Facts.new("nonmatchingnode3"                                                         ),
        },
        {'facts.processor_count.lt' => '50'}
      )
    end

    it "should return node names that match the search query options with the less than or equal to operator" do
      assert_search_matches({
          'matching.yaml'  => Puppet::Node::Facts.new("matchingnode",  "architecture" => "i386",    'processor_count' => '5'),
          'matching1.yaml' => Puppet::Node::Facts.new("matchingnode1", "architecture" => "powerpc", 'processor_count' => '50', 'randomfact' => 'foo')
        },
        {
          "nonmatching.yaml"  => Puppet::Node::Facts.new("nonmatchingnode",  "architecture" => "powerpc", 'processor_count' => '100' ),
          "nonmatching2.yaml" => Puppet::Node::Facts.new("nonmatchingnode2", "architecture" => "i386",    'processor_count' => '5000'),
          "nonmatching3.yaml" => Puppet::Node::Facts.new("nonmatchingnode3"                                                          ),
        },
        {'facts.processor_count.le' => '50'}
      )
    end

    it "should return node names that match the search query options with the greater than or equal to operator" do
      assert_search_matches({
          'matching.yaml'  => Puppet::Node::Facts.new("matchingnode",  "architecture" => "i386",    'processor_count' => '100'),
          'matching1.yaml' => Puppet::Node::Facts.new("matchingnode1", "architecture" => "powerpc", 'processor_count' => '50', 'randomfact' => 'foo')
        },
        {
          "nonmatching.yaml"  => Puppet::Node::Facts.new("nonmatchingnode",  "architecture" => "powerpc", 'processor_count' => '40'),
          "nonmatching2.yaml" => Puppet::Node::Facts.new("nonmatchingnode2", "architecture" => "i386",    'processor_count' => '9' ),
          "nonmatching3.yaml" => Puppet::Node::Facts.new("nonmatchingnode3"                                                        ),
        },
        {'facts.processor_count.ge' => '50'}
      )
    end

    it "should return node names that match the search query options with the not equal operator" do
      assert_search_matches({
          'matching.yaml'  => Puppet::Node::Facts.new("matchingnode",  "architecture" => 'arm'                           ),
          'matching1.yaml' => Puppet::Node::Facts.new("matchingnode1", "architecture" => 'powerpc', 'randomfact' => 'foo')
        },
        {
          "nonmatching.yaml"  => Puppet::Node::Facts.new("nonmatchingnode",  "architecture" => "i386"                           ),
          "nonmatching2.yaml" => Puppet::Node::Facts.new("nonmatchingnode2", "architecture" => "i386", 'processor_count' => '9' ),
          "nonmatching3.yaml" => Puppet::Node::Facts.new("nonmatchingnode3"                                                     ),
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
          '2010-11-01.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-11-01", {}), Time.parse("2010-11-01")),
          '2010-11-10.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-11-10", {}), Time.parse("2010-11-10")),
        },
        {
          '2010-10-01.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-01", {}), Time.parse("2010-10-01")),
          '2010-10-10.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-10", {}), Time.parse("2010-10-10")),
          '2010-10-15.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-15", {}), Time.parse("2010-10-15")),
        },
        {'meta.timestamp.gt' => '2010-10-15'}
      )
    end

    it "should be able to query based on meta.timestamp.le" do
      assert_search_matches({
          '2010-10-01.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-01", {}), Time.parse("2010-10-01")),
          '2010-10-10.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-10", {}), Time.parse("2010-10-10")),
          '2010-10-15.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-15", {}), Time.parse("2010-10-15")),
        },
        {
          '2010-11-01.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-11-01", {}), Time.parse("2010-11-01")),
          '2010-11-10.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-11-10", {}), Time.parse("2010-11-10")),
        },
        {'meta.timestamp.le' => '2010-10-15'}
      )
    end

    it "should be able to query based on meta.timestamp.lt" do
      assert_search_matches({
          '2010-10-01.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-01", {}), Time.parse("2010-10-01")),
          '2010-10-10.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-10", {}), Time.parse("2010-10-10")),
        },
        {
          '2010-11-01.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-11-01", {}), Time.parse("2010-11-01")),
          '2010-11-10.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-11-10", {}), Time.parse("2010-11-10")),
          '2010-10-15.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-15", {}), Time.parse("2010-10-15")),
        },
        {'meta.timestamp.lt' => '2010-10-15'}
      )
    end

    it "should be able to query based on meta.timestamp.ge" do
      assert_search_matches({
          '2010-11-01.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-11-01", {}), Time.parse("2010-11-01")),
          '2010-11-10.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-11-10", {}), Time.parse("2010-11-10")),
          '2010-10-15.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-15", {}), Time.parse("2010-10-15")),
        },
        {
          '2010-10-01.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-01", {}), Time.parse("2010-10-01")),
          '2010-10-10.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-10", {}), Time.parse("2010-10-10")),
        },
        {'meta.timestamp.ge' => '2010-10-15'}
      )
    end

    it "should be able to query based on meta.timestamp.eq" do
      assert_search_matches({
          '2010-10-15.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-15", {}), Time.parse("2010-10-15")),
        },
        {
          '2010-11-01.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-11-01", {}), Time.parse("2010-11-01")),
          '2010-11-10.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-11-10", {}), Time.parse("2010-11-10")),
          '2010-10-01.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-01", {}), Time.parse("2010-10-01")),
          '2010-10-10.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-10", {}), Time.parse("2010-10-10")),
        },
        {'meta.timestamp.eq' => '2010-10-15'}
      )
    end

    it "should be able to query based on meta.timestamp" do
      assert_search_matches({
          '2010-10-15.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-15", {}), Time.parse("2010-10-15")),
        },
        {
          '2010-11-01.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-11-01", {}), Time.parse("2010-11-01")),
          '2010-11-10.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-11-10", {}), Time.parse("2010-11-10")),
          '2010-10-01.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-01", {}), Time.parse("2010-10-01")),
          '2010-10-10.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-10", {}), Time.parse("2010-10-10")),
        },
        {'meta.timestamp' => '2010-10-15'}
      )
    end

    it "should be able to query based on meta.timestamp.ne" do
      assert_search_matches({
          '2010-11-01.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-11-01", {}), Time.parse("2010-11-01")),
          '2010-11-10.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-11-10", {}), Time.parse("2010-11-10")),
          '2010-10-01.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-01", {}), Time.parse("2010-10-01")),
          '2010-10-10.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-10", {}), Time.parse("2010-10-10")),
        },
        {
          '2010-10-15.yaml' => apply_timestamp(Puppet::Node::Facts.new("2010-10-15", {}), Time.parse("2010-10-15")),
        },
        {'meta.timestamp.ne' => '2010-10-15'}
      )
    end
  end
end
