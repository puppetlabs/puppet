require 'spec_helper'
require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'node statements' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  shared_examples_for 'nodes' do
    it 'selects a node where the name is just a number' do
      # Future parser doesn't allow a number in this position
      catalog = compile_to_catalog(<<-MANIFEST, Puppet::Node.new("5"))
      node 5 { notify { 'matched': } }
      MANIFEST

      expect(catalog).to have_resource('Notify[matched]')
    end

    it 'selects the node with a matching name' do
      catalog = compile_to_catalog(<<-MANIFEST, Puppet::Node.new("nodename"))
      node noden {}
      node nodename { notify { matched: } }
      node name {}
      MANIFEST

      expect(catalog).to have_resource('Notify[matched]')
    end

    it 'prefers a node with a literal name over one with a regex' do
      catalog = compile_to_catalog(<<-MANIFEST, Puppet::Node.new("nodename"))
      node /noden.me/ { notify { ignored: } }
      node nodename { notify { matched: } }
      MANIFEST

      expect(catalog).to have_resource('Notify[matched]')
    end

    it 'selects a node where one of the names matches' do
      catalog = compile_to_catalog(<<-MANIFEST, Puppet::Node.new("nodename"))
      node different, nodename, other { notify { matched: } }
      MANIFEST

      expect(catalog).to have_resource('Notify[matched]')
    end

    it 'arbitrarily selects one of the matching nodes' do
      catalog = compile_to_catalog(<<-MANIFEST, Puppet::Node.new("nodename"))
      node /not/ { notify { 'is not matched': } }
      node /name.*/ { notify { 'could be matched': } }
      node /na.e/ { notify { 'could also be matched': } }
      MANIFEST

      expect([catalog.resource('Notify[could be matched]'), catalog.resource('Notify[could also be matched]')].compact).to_not be_empty
    end

    it 'selects a node where one of the names matches with a mixture of literals and regex' do
      catalog = compile_to_catalog(<<-MANIFEST, Puppet::Node.new("nodename"))
      node different, /name/, other { notify { matched: } }
      MANIFEST

      expect(catalog).to have_resource('Notify[matched]')
    end

    it 'errors when two nodes with regexes collide after some regex syntax is removed' do
      expect do
        compile_to_catalog(<<-MANIFEST)
        node /a.*(c)?/ { }
        node 'a.c' { }
        MANIFEST
      end.to raise_error(Puppet::Error, /Node 'a.c' is already defined/)
    end

    it 'provides captures from the regex in the node body' do
      catalog = compile_to_catalog(<<-MANIFEST, Puppet::Node.new("nodename"))
      node /(.*)/ { notify { "$1": } }
      MANIFEST

      expect(catalog).to have_resource('Notify[nodename]')
    end

    it 'selects the node with the matching regex' do
      catalog = compile_to_catalog(<<-MANIFEST, Puppet::Node.new("nodename"))
      node /node.*/ { notify { matched: } }
      MANIFEST

      expect(catalog).to have_resource('Notify[matched]')
    end

    it 'selects a node that is a literal string' do
      catalog = compile_to_catalog(<<-MANIFEST, Puppet::Node.new("node.name"))
      node 'node.name' { notify { matched: } }
      MANIFEST

      expect(catalog).to have_resource('Notify[matched]')
    end

    it 'selects a node that is a prefix of the agent name' do
      Puppet[:strict_hostname_checking] = false
      catalog = compile_to_catalog(<<-MANIFEST, Puppet::Node.new("node.name.com"))
      node 'node.name' { notify { matched: } }
      MANIFEST

      expect(catalog).to have_resource('Notify[matched]')
    end

    it 'does not treat regex symbols as a regex inside a string literal' do
      catalog = compile_to_catalog(<<-MANIFEST, Puppet::Node.new("nodexname"))
      node 'node.name' { notify { 'not matched': } }
      node 'nodexname' { notify { 'matched': } }
      MANIFEST

      expect(catalog).to have_resource('Notify[matched]')
    end

    it 'errors when two nodes have the same name' do
      expect do
        compile_to_catalog(<<-MANIFEST)
        node name { }
        node 'name' { }
        MANIFEST
      end.to raise_error(Puppet::Error, /Node 'name' is already defined/)
    end
  end

  describe 'using classic parser' do
    before :each do
      Puppet[:parser] = 'current'
    end

    it_behaves_like 'nodes'

    it 'includes the inherited nodes of the matching node' do
      catalog = compile_to_catalog(<<-MANIFEST, Puppet::Node.new("nodename"))
      node notmatched1 { notify { inherited: } }
      node nodename inherits notmatched1 { notify { matched: } }
      node notmatched2 { notify { ignored: } }
      MANIFEST

      expect(catalog).to have_resource('Notify[matched]')
      expect(catalog).to have_resource('Notify[inherited]')
    end

    it 'raises deprecation warning for node inheritance for 3x parser' do
      Puppet.expects(:warning).at_least_once
      Puppet.expects(:warning).with(regexp_matches(/Deprecation notice\: Node inheritance is not supported in Puppet >= 4\.0\.0/))

      catalog = compile_to_catalog(<<-MANIFEST, Puppet::Node.new("1.2.3.4"))
        node default {}
        node '1.2.3.4' inherits default {  }
      MANIFEST
    end
  end

  describe 'using future parser' do
    before :each do
      Puppet[:parser] = 'future'
    end

    it_behaves_like 'nodes'

    it 'is unable to parse a name that is an invalid number' do
      expect do
        compile_to_catalog('node 5name {} ')
      end.to raise_error(Puppet::Error, /Illegal number/)
    end

    it 'parses a node name that is dotted numbers' do
      catalog = compile_to_catalog(<<-MANIFEST, Puppet::Node.new("1.2.3.4"))
        node 1.2.3.4 { notify { matched: } }
      MANIFEST

      expect(catalog).to have_resource('Notify[matched]')
    end

    it 'raises error for node inheritance' do
      expect do
        compile_to_catalog(<<-MANIFEST, Puppet::Node.new("nodename"))
        node default {}
          node nodename inherits default {  }
        MANIFEST
      end.to raise_error(/Node inheritance is not supported in Puppet >= 4\.0\.0/)
    end

  end
end
