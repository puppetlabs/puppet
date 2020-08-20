require 'spec_helper'

require 'puppet/node/facts'
require 'puppet/indirector/facts/json'

def dir_containing_json_facts(hash)
  jsondir = tmpdir('json_facts')

  Puppet[:client_datadir] = jsondir
  dir = File.join(jsondir, 'facts')
  Dir.mkdir(dir)
  hash.each_pair do |file, facts|
    File.open(File.join(dir, file), 'wb') do |f|
      f.write(JSON.dump(facts))
    end
  end
end

describe Puppet::Node::Facts::Json do
  include PuppetSpec::Files

  it "should be a subclass of the Json terminus" do
    expect(Puppet::Node::Facts::Json.superclass).to equal(Puppet::Indirector::JSON)
  end

  it "should have documentation" do
    expect(Puppet::Node::Facts::Json.doc).not_to be_nil
    expect(Puppet::Node::Facts::Json.doc).not_to be_empty
  end

  it "should be registered with the facts indirection" do
    indirection = Puppet::Indirector::Indirection.instance(:facts)
    expect(Puppet::Node::Facts::Json.indirection).to equal(indirection)
  end

  it "should have its name set to :json" do
    expect(Puppet::Node::Facts::Json.name).to eq(:json)
  end

  it "should allow network requests" do
    # Doesn't allow json as a network format, but allows `puppet facts upload`
    # to update the JSON cache on a master.
    expect(Puppet::Node::Facts::Json.new.allow_remote_requests?).to be(true)
  end

  describe "#search" do
    def assert_search_matches(matching, nonmatching, query)
      request = Puppet::Indirector::Request.new(:inventory, :search, nil, nil, query)

      dir_containing_json_facts(matching.merge(nonmatching))

      results = Puppet::Node::Facts::Json.new.search(request)
      expect(results).to match_array(matching.values.map {|facts| facts.name})
    end

    it "should return node names that match the search query options" do
      assert_search_matches({
          'matching.json'  => Puppet::Node::Facts.new("matchingnode",  "architecture" => "i386", 'processor_count' => '4'),
          'matching1.json' => Puppet::Node::Facts.new("matchingnode1", "architecture" => "i386", 'processor_count' => '4', 'randomfact' => 'foo')
        },
        {
          "nonmatching.json"  => Puppet::Node::Facts.new("nonmatchingnode",  "architecture" => "powerpc", 'processor_count' => '4'),
          "nonmatching1.json" => Puppet::Node::Facts.new("nonmatchingnode1", "architecture" => "powerpc", 'processor_count' => '5'),
          "nonmatching2.json" => Puppet::Node::Facts.new("nonmatchingnode2", "architecture" => "i386",    'processor_count' => '5'),
          "nonmatching3.json" => Puppet::Node::Facts.new("nonmatchingnode3",                              'processor_count' => '4'),
        },
        {'facts.architecture' => 'i386', 'facts.processor_count' => '4'}
      )
    end

    it "should return empty array when no nodes match the search query options" do
      assert_search_matches({}, {
          "nonmatching.json"  => Puppet::Node::Facts.new("nonmatchingnode",  "architecture" => "powerpc", 'processor_count' => '10'),
          "nonmatching1.json" => Puppet::Node::Facts.new("nonmatchingnode1", "architecture" => "powerpc", 'processor_count' => '5'),
          "nonmatching2.json" => Puppet::Node::Facts.new("nonmatchingnode2", "architecture" => "i386",    'processor_count' => '5'),
          "nonmatching3.json" => Puppet::Node::Facts.new("nonmatchingnode3",                              'processor_count' => '4'),
        },
        {'facts.processor_count.lt' => '4', 'facts.processor_count.gt' => '4'}
      )
    end

    it "should return node names that match the search query options with the greater than operator" do
      assert_search_matches({
          'matching.json'  => Puppet::Node::Facts.new("matchingnode",  "architecture" => "i386",    'processor_count' => '5'),
          'matching1.json' => Puppet::Node::Facts.new("matchingnode1", "architecture" => "powerpc", 'processor_count' => '10', 'randomfact' => 'foo')
        },
        {
          "nonmatching.json"  => Puppet::Node::Facts.new("nonmatchingnode",  "architecture" => "powerpc", 'processor_count' => '4'),
          "nonmatching2.json" => Puppet::Node::Facts.new("nonmatchingnode2", "architecture" => "i386",    'processor_count' => '3'),
          "nonmatching3.json" => Puppet::Node::Facts.new("nonmatchingnode3"                                                       ),
        },
        {'facts.processor_count.gt' => '4'}
      )
    end

    it "should return node names that match the search query options with the less than operator" do
      assert_search_matches({
          'matching.json'  => Puppet::Node::Facts.new("matchingnode",  "architecture" => "i386",    'processor_count' => '5'),
          'matching1.json' => Puppet::Node::Facts.new("matchingnode1", "architecture" => "powerpc", 'processor_count' => '30', 'randomfact' => 'foo')
        },
        {
          "nonmatching.json"  => Puppet::Node::Facts.new("nonmatchingnode",  "architecture" => "powerpc", 'processor_count' => '50' ),
          "nonmatching2.json" => Puppet::Node::Facts.new("nonmatchingnode2", "architecture" => "i386",    'processor_count' => '100'),
          "nonmatching3.json" => Puppet::Node::Facts.new("nonmatchingnode3"                                                         ),
        },
        {'facts.processor_count.lt' => '50'}
      )
    end

    it "should return node names that match the search query options with the less than or equal to operator" do
      assert_search_matches({
          'matching.json'  => Puppet::Node::Facts.new("matchingnode",  "architecture" => "i386",    'processor_count' => '5'),
          'matching1.json' => Puppet::Node::Facts.new("matchingnode1", "architecture" => "powerpc", 'processor_count' => '50', 'randomfact' => 'foo')
        },
        {
          "nonmatching.json"  => Puppet::Node::Facts.new("nonmatchingnode",  "architecture" => "powerpc", 'processor_count' => '100' ),
          "nonmatching2.json" => Puppet::Node::Facts.new("nonmatchingnode2", "architecture" => "i386",    'processor_count' => '5000'),
          "nonmatching3.json" => Puppet::Node::Facts.new("nonmatchingnode3"                                                          ),
        },
        {'facts.processor_count.le' => '50'}
      )
    end

    it "should return node names that match the search query options with the greater than or equal to operator" do
      assert_search_matches({
          'matching.json'  => Puppet::Node::Facts.new("matchingnode",  "architecture" => "i386",    'processor_count' => '100'),
          'matching1.json' => Puppet::Node::Facts.new("matchingnode1", "architecture" => "powerpc", 'processor_count' => '50', 'randomfact' => 'foo')
        },
        {
          "nonmatching.json"  => Puppet::Node::Facts.new("nonmatchingnode",  "architecture" => "powerpc", 'processor_count' => '40'),
          "nonmatching2.json" => Puppet::Node::Facts.new("nonmatchingnode2", "architecture" => "i386",    'processor_count' => '9' ),
          "nonmatching3.json" => Puppet::Node::Facts.new("nonmatchingnode3"                                                        ),
        },
        {'facts.processor_count.ge' => '50'}
      )
    end

    it "should return node names that match the search query options with the not equal operator" do
      assert_search_matches({
          'matching.json'  => Puppet::Node::Facts.new("matchingnode",  "architecture" => 'arm'                           ),
          'matching1.json' => Puppet::Node::Facts.new("matchingnode1", "architecture" => 'powerpc', 'randomfact' => 'foo')
        },
        {
          "nonmatching.json"  => Puppet::Node::Facts.new("nonmatchingnode",  "architecture" => "i386"                           ),
          "nonmatching2.json" => Puppet::Node::Facts.new("nonmatchingnode2", "architecture" => "i386", 'processor_count' => '9' ),
          "nonmatching3.json" => Puppet::Node::Facts.new("nonmatchingnode3"                                                     ),
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
          '2010-11-01.json' => apply_timestamp(Puppet::Node::Facts.new("2010-11-01", {}), Time.parse("2010-11-01")),
          '2010-11-10.json' => apply_timestamp(Puppet::Node::Facts.new("2010-11-10", {}), Time.parse("2010-11-10")),
        },
        {
          '2010-10-01.json' => apply_timestamp(Puppet::Node::Facts.new("2010-10-01", {}), Time.parse("2010-10-01")),
          '2010-10-10.json' => apply_timestamp(Puppet::Node::Facts.new("2010-10-10", {}), Time.parse("2010-10-10")),
          '2010-10-15.json' => apply_timestamp(Puppet::Node::Facts.new("2010-10-15", {}), Time.parse("2010-10-15")),
        },
        {'meta.timestamp.gt' => '2010-10-15'}
      )
    end

    it "should be able to query based on meta.timestamp.le" do
      assert_search_matches({
          '2010-10-01.json' => apply_timestamp(Puppet::Node::Facts.new("2010-10-01", {}), Time.parse("2010-10-01")),
          '2010-10-10.json' => apply_timestamp(Puppet::Node::Facts.new("2010-10-10", {}), Time.parse("2010-10-10")),
          '2010-10-15.json' => apply_timestamp(Puppet::Node::Facts.new("2010-10-15", {}), Time.parse("2010-10-15")),
        },
        {
          '2010-11-01.json' => apply_timestamp(Puppet::Node::Facts.new("2010-11-01", {}), Time.parse("2010-11-01")),
          '2010-11-10.json' => apply_timestamp(Puppet::Node::Facts.new("2010-11-10", {}), Time.parse("2010-11-10")),
        },
        {'meta.timestamp.le' => '2010-10-15'}
      )
    end

    it "should be able to query based on meta.timestamp.lt" do
      assert_search_matches({
          '2010-10-01.json' => apply_timestamp(Puppet::Node::Facts.new("2010-10-01", {}), Time.parse("2010-10-01")),
          '2010-10-10.json' => apply_timestamp(Puppet::Node::Facts.new("2010-10-10", {}), Time.parse("2010-10-10")),
        },
        {
          '2010-11-01.json' => apply_timestamp(Puppet::Node::Facts.new("2010-11-01", {}), Time.parse("2010-11-01")),
          '2010-11-10.json' => apply_timestamp(Puppet::Node::Facts.new("2010-11-10", {}), Time.parse("2010-11-10")),
          '2010-10-15.json' => apply_timestamp(Puppet::Node::Facts.new("2010-10-15", {}), Time.parse("2010-10-15")),
        },
        {'meta.timestamp.lt' => '2010-10-15'}
      )
    end

    it "should be able to query based on meta.timestamp.ge" do
      assert_search_matches({
          '2010-11-01.json' => apply_timestamp(Puppet::Node::Facts.new("2010-11-01", {}), Time.parse("2010-11-01")),
          '2010-11-10.json' => apply_timestamp(Puppet::Node::Facts.new("2010-11-10", {}), Time.parse("2010-11-10")),
          '2010-10-15.json' => apply_timestamp(Puppet::Node::Facts.new("2010-10-15", {}), Time.parse("2010-10-15")),
        },
        {
          '2010-10-01.json' => apply_timestamp(Puppet::Node::Facts.new("2010-10-01", {}), Time.parse("2010-10-01")),
          '2010-10-10.json' => apply_timestamp(Puppet::Node::Facts.new("2010-10-10", {}), Time.parse("2010-10-10")),
        },
        {'meta.timestamp.ge' => '2010-10-15'}
      )
    end

    it "should be able to query based on meta.timestamp.eq" do
      assert_search_matches({
          '2010-10-15.json' => apply_timestamp(Puppet::Node::Facts.new("2010-10-15", {}), Time.parse("2010-10-15")),
        },
        {
          '2010-11-01.json' => apply_timestamp(Puppet::Node::Facts.new("2010-11-01", {}), Time.parse("2010-11-01")),
          '2010-11-10.json' => apply_timestamp(Puppet::Node::Facts.new("2010-11-10", {}), Time.parse("2010-11-10")),
          '2010-10-01.json' => apply_timestamp(Puppet::Node::Facts.new("2010-10-01", {}), Time.parse("2010-10-01")),
          '2010-10-10.json' => apply_timestamp(Puppet::Node::Facts.new("2010-10-10", {}), Time.parse("2010-10-10")),
        },
        {'meta.timestamp.eq' => '2010-10-15'}
      )
    end

    it "should be able to query based on meta.timestamp" do
      assert_search_matches({
          '2010-10-15.json' => apply_timestamp(Puppet::Node::Facts.new("2010-10-15", {}), Time.parse("2010-10-15")),
        },
        {
          '2010-11-01.json' => apply_timestamp(Puppet::Node::Facts.new("2010-11-01", {}), Time.parse("2010-11-01")),
          '2010-11-10.json' => apply_timestamp(Puppet::Node::Facts.new("2010-11-10", {}), Time.parse("2010-11-10")),
          '2010-10-01.json' => apply_timestamp(Puppet::Node::Facts.new("2010-10-01", {}), Time.parse("2010-10-01")),
          '2010-10-10.json' => apply_timestamp(Puppet::Node::Facts.new("2010-10-10", {}), Time.parse("2010-10-10")),
        },
        {'meta.timestamp' => '2010-10-15'}
      )
    end

    it "should be able to query based on meta.timestamp.ne" do
      assert_search_matches({
          '2010-11-01.json' => apply_timestamp(Puppet::Node::Facts.new("2010-11-01", {}), Time.parse("2010-11-01")),
          '2010-11-10.json' => apply_timestamp(Puppet::Node::Facts.new("2010-11-10", {}), Time.parse("2010-11-10")),
          '2010-10-01.json' => apply_timestamp(Puppet::Node::Facts.new("2010-10-01", {}), Time.parse("2010-10-01")),
          '2010-10-10.json' => apply_timestamp(Puppet::Node::Facts.new("2010-10-10", {}), Time.parse("2010-10-10")),
        },
        {
          '2010-10-15.json' => apply_timestamp(Puppet::Node::Facts.new("2010-10-15", {}), Time.parse("2010-10-15")),
        },
        {'meta.timestamp.ne' => '2010-10-15'}
      )
    end
  end
end
