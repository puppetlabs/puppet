#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/node/inventory'
require 'puppet/indirector/inventory/yaml'
require 'puppet/indirector/request'

describe Puppet::Node::Inventory::Yaml do
  def setup_search_matching(matching, nonmatching, query)
    request = Puppet::Indirector::Request.new(:inventory, :search, nil, query)

    Dir.stubs(:glob).returns(matching.keys + nonmatching.keys)
    [matching, nonmatching].each do |examples|
      examples.each do |key, value|
        YAML.stubs(:load_file).with(key).returns value
      end
    end
    return matching, request
  end

  it "should return node names that match the search query options" do
    matching, request = setup_search_matching({
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
    Puppet::Node::Inventory::Yaml.new.search(request).should =~ matching.values.map {|facts| facts.name}
  end

  it "should return empty array when no nodes match the search query options" do
    matching, request = setup_search_matching({}, {
        "/path/to/nonmatching.yaml"  => Puppet::Node::Facts.new("nonmatchingnode",  "architecture" => "powerpc", 'processor_count' => '10'),
        "/path/to/nonmatching1.yaml" => Puppet::Node::Facts.new("nonmatchingnode1", "architecture" => "powerpc", 'processor_count' => '5'),
        "/path/to/nonmatching2.yaml" => Puppet::Node::Facts.new("nonmatchingnode2", "architecture" => "i386",    'processor_count' => '5'),
        "/path/to/nonmatching3.yaml" => Puppet::Node::Facts.new("nonmatchingnode3",                              'processor_count' => '4'),
      },
      {'facts.processor_count.lt' => '4', 'facts.processor_count.gt' => '4'}
    )
    Puppet::Node::Inventory::Yaml.new.search(request).should =~ matching.values.map {|facts| facts.name}
  end


  it "should return node names that match the search query options with the greater than operator" do
    matching, request = setup_search_matching({
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

    Puppet::Node::Inventory::Yaml.new.search(request).should =~ matching.values.map {|facts| facts.name}
  end

  it "should return node names that match the search query options with the less than operator" do
    matching, request = setup_search_matching({
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

    Puppet::Node::Inventory::Yaml.new.search(request).should =~ matching.values.map {|facts| facts.name}
  end

  it "should return node names that match the search query options with the less than or equal to operator" do
    matching, request = setup_search_matching({
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

    Puppet::Node::Inventory::Yaml.new.search(request).should =~ matching.values.map {|facts| facts.name}
  end

  it "should return node names that match the search query options with the greater than or equal to operator" do
    matching, request = setup_search_matching({
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

    Puppet::Node::Inventory::Yaml.new.search(request).should =~ matching.values.map {|facts| facts.name}
  end

  it "should return node names that match the search query options with the not equal operator" do
    matching, request = setup_search_matching({
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

    Puppet::Node::Inventory::Yaml.new.search(request).should =~ matching.values.map {|facts| facts.name}
  end
end
