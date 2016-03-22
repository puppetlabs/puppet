#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/node/ldap'

describe Puppet::Node::Ldap do
  let(:nodename) { "mynode.domain.com" }
  let(:node_indirection) { Puppet::Node::Ldap.new }
  let(:environment) { Puppet::Node::Environment.create(:myenv, []) }
  let(:fact_values) { {:afact => "a value", "one" => "boo"} }
  let(:facts) { Puppet::Node::Facts.new(nodename, fact_values) }

  before do
    Puppet::Node::Facts.indirection.stubs(:find).with(nodename, :environment => environment).returns(facts)
  end

  describe "when searching for a single node" do
    let(:request) { Puppet::Indirector::Request.new(:node, :find, nodename, nil, :environment => environment) }

    it "should convert the hostname into a search filter" do
      entry = stub 'entry', :dn => 'cn=mynode.domain.com,ou=hosts,dc=madstop,dc=com', :vals => %w{}, :to_hash => {}
      node_indirection.expects(:ldapsearch).with("(&(objectclass=puppetClient)(cn=#{nodename}))").yields entry
      node_indirection.name2hash(nodename)
    end

    it "should convert any found entry into a hash" do
      entry = stub 'entry', :dn => 'cn=mynode.domain.com,ou=hosts,dc=madstop,dc=com', :vals => %w{}, :to_hash => {}
      node_indirection.expects(:ldapsearch).with("(&(objectclass=puppetClient)(cn=#{nodename}))").yields entry
      myhash = {"myhash" => true}
      node_indirection.expects(:entry2hash).with(entry).returns myhash
      expect(node_indirection.name2hash(nodename)).to eq(myhash)
    end

    # This heavily tests our entry2hash method, so we don't have to stub out the stupid entry information any more.
    describe "when an ldap entry is found" do
      before do
        @entry = stub 'entry', :dn => 'cn=mynode,ou=hosts,dc=madstop,dc=com', :vals => %w{}, :to_hash => {}
        node_indirection.stubs(:ldapsearch).yields @entry
      end

      it "should convert the entry to a hash" do
        expect(node_indirection.entry2hash(@entry)).to be_instance_of(Hash)
      end

      it "should add the entry's common name to the hash if fqdn if false" do
        expect(node_indirection.entry2hash(@entry,fqdn = false)[:name]).to eq("mynode")
      end

      it "should add the entry's fqdn name to the hash if fqdn if true" do
        expect(node_indirection.entry2hash(@entry,fqdn = true)[:name]).to eq("mynode.madstop.com")
      end

      it "should add all of the entry's classes to the hash" do
        @entry.stubs(:vals).with("puppetclass").returns %w{one two}
        expect(node_indirection.entry2hash(@entry)[:classes]).to eq(%w{one two})
      end

      it "should deduplicate class values" do
        @entry.stubs(:to_hash).returns({})
        node_indirection.stubs(:class_attributes).returns(%w{one two})
        @entry.stubs(:vals).with("one").returns(%w{a b})
        @entry.stubs(:vals).with("two").returns(%w{b c})
        expect(node_indirection.entry2hash(@entry)[:classes]).to eq(%w{a b c})
      end

      it "should add the entry's environment to the hash" do
        @entry.stubs(:to_hash).returns("environment" => %w{production})
        expect(node_indirection.entry2hash(@entry)[:environment]).to eq("production")
      end

      it "should add all stacked parameters as parameters in the hash" do
        @entry.stubs(:vals).with("puppetvar").returns(%w{one=two three=four})
        result = node_indirection.entry2hash(@entry)
        expect(result[:parameters]["one"]).to eq("two")
        expect(result[:parameters]["three"]).to eq("four")
      end

      it "should not add the stacked parameter as a normal parameter" do
        @entry.stubs(:vals).with("puppetvar").returns(%w{one=two three=four})
        @entry.stubs(:to_hash).returns("puppetvar" => %w{one=two three=four})
        expect(node_indirection.entry2hash(@entry)[:parameters]["puppetvar"]).to be_nil
      end

      it "should add all other attributes as parameters in the hash" do
        @entry.stubs(:to_hash).returns("foo" => %w{one two})
        expect(node_indirection.entry2hash(@entry)[:parameters]["foo"]).to eq(%w{one two})
      end

      it "should return single-value parameters as strings, not arrays" do
        @entry.stubs(:to_hash).returns("foo" => %w{one})
        expect(node_indirection.entry2hash(@entry)[:parameters]["foo"]).to eq("one")
      end

      it "should convert 'true' values to the boolean 'true'" do
        @entry.stubs(:to_hash).returns({"one" => ["true"]})
        expect(node_indirection.entry2hash(@entry)[:parameters]["one"]).to eq(true)
      end

      it "should convert 'false' values to the boolean 'false'" do
        @entry.stubs(:to_hash).returns({"one" => ["false"]})
        expect(node_indirection.entry2hash(@entry)[:parameters]["one"]).to eq(false)
      end

      it "should convert 'true' values to the boolean 'true' inside an array" do
        @entry.stubs(:to_hash).returns({"one" => ["true", "other"]})
        expect(node_indirection.entry2hash(@entry)[:parameters]["one"]).to eq([true, "other"])
      end

      it "should convert 'false' values to the boolean 'false' inside an array" do
        @entry.stubs(:to_hash).returns({"one" => ["false", "other"]})
        expect(node_indirection.entry2hash(@entry)[:parameters]["one"]).to eq([false, "other"])
      end

      it "should add the parent's name if present" do
        @entry.stubs(:vals).with("parentnode").returns(%w{foo})
        expect(node_indirection.entry2hash(@entry)[:parent]).to eq("foo")
      end

      it "should fail if more than one parent is specified" do
        @entry.stubs(:vals).with("parentnode").returns(%w{foo})
        expect(node_indirection.entry2hash(@entry)[:parent]).to eq("foo")
      end
    end

    it "should search first for the provided key" do
      node_indirection.expects(:name2hash).with("mynode.domain.com").returns({})
      node_indirection.find(request)
    end

    it "should search for the short version of the provided key if the key looks like a hostname and no results are found for the key itself" do
      node_indirection.expects(:name2hash).with("mynode.domain.com").returns(nil)
      node_indirection.expects(:name2hash).with("mynode").returns({})
      node_indirection.find(request)
    end

    it "should search for default information if no information can be found for the key" do
      node_indirection.expects(:name2hash).with("mynode.domain.com").returns(nil)
      node_indirection.expects(:name2hash).with("mynode").returns(nil)
      node_indirection.expects(:name2hash).with("default").returns({})
      node_indirection.find(request)
    end

    it "should return nil if no results are found in ldap" do
      node_indirection.stubs(:name2hash).returns nil
      expect(node_indirection.find(request)).to be_nil
    end

    it "should return a node object if results are found in ldap" do
      node_indirection.stubs(:name2hash).returns({})
      expect(node_indirection.find(request)).to be
    end

    describe "and node information is found in LDAP" do
      before do
        @result = {}
        node_indirection.stubs(:name2hash).returns @result
      end

      it "should create the node with the correct name, even if it was found by a different name" do
        node_indirection.expects(:name2hash).with(nodename).returns nil
        node_indirection.expects(:name2hash).with("mynode").returns @result

        expect(node_indirection.find(request).name).to eq(nodename)
      end

      it "should add any classes from ldap" do
        classes = %w{a b c d}
        @result[:classes] = classes
        expect(node_indirection.find(request).classes).to eq(classes)
      end

      it "should add all entry attributes as node parameters" do
        params = {"one" => "two", "three" => "four"}
        @result[:parameters] = params
        expect(node_indirection.find(request).parameters).to include(params)
      end

      it "should set the node's environment to the environment of the results" do
        result_env = Puppet::Node::Environment.create(:local_test, [])
        Puppet::Node::Facts.indirection.stubs(:find).with(nodename, :environment => result_env).returns(facts)
        @result[:environment] = "local_test"

        Puppet.override(:environments => Puppet::Environments::Static.new(result_env)) do
          expect(node_indirection.find(request).environment).to eq(result_env)
        end
      end

      it "should retain false parameter values" do
        @result[:parameters] = {}
        @result[:parameters]["one"] = false
        expect(node_indirection.find(request).parameters).to include({"one" => false})
      end

      it "should merge the node's facts after the parameters from ldap are assigned" do
        # Make sure we've got data to start with, so the parameters are actually set.
        params = {"one" => "yay", "two" => "hooray"}
        @result[:parameters] = params

        # Node implements its own merge so that an existing param takes
        # precedence over facts. We get the same result here by merging params
        # into facts
        expect(node_indirection.find(request).parameters).to eq(facts.values.merge(params))
      end

      describe "and a parent node is specified" do
        before do
          @entry = {:classes => [], :parameters => {}}
          @parent = {:classes => [], :parameters => {}}
          @parent_parent = {:classes => [], :parameters => {}}

          node_indirection.stubs(:name2hash).with(nodename).returns(@entry)
          node_indirection.stubs(:name2hash).with('parent').returns(@parent)
          node_indirection.stubs(:name2hash).with('parent_parent').returns(@parent_parent)

          node_indirection.stubs(:parent_attribute).returns(:parent)
        end

        it "should search for the parent node" do
          @entry[:parent] = "parent"
          node_indirection.expects(:name2hash).with(nodename).returns @entry
          node_indirection.expects(:name2hash).with('parent').returns @parent

          node_indirection.find(request)
        end

        it "should fail if the parent cannot be found" do
          @entry[:parent] = "parent"

          node_indirection.expects(:name2hash).with('parent').returns nil

          expect { node_indirection.find(request) }.to raise_error(Puppet::Error, /Could not find parent node/)
        end

        it "should add any parent classes to the node's classes" do
          @entry[:parent] = "parent"
          @entry[:classes] = %w{a b}

          @parent[:classes] = %w{c d}

          expect(node_indirection.find(request).classes).to eq(%w{a b c d})
        end

        it "should add any parent parameters to the node's parameters" do
          @entry[:parent] = "parent"
          @entry[:parameters]["one"] = "two"

          @parent[:parameters]["three"] = "four"

          expect(node_indirection.find(request).parameters).to include({"one" => "two", "three" => "four"})
        end

        it "should prefer node parameters over parent parameters" do
          @entry[:parent] = "parent"
          @entry[:parameters]["one"] = "two"

          @parent[:parameters]["one"] = "three"

          expect(node_indirection.find(request).parameters).to include({"one" => "two"})
        end

        it "should use the parent's environment if the node has none" do
          env = Puppet::Node::Environment.create(:parent, [])
          @entry[:parent] = "parent"

          @parent[:environment] = "parent"

          Puppet::Node::Facts.indirection.stubs(:find).with(nodename, :environment => env).returns(facts)

          Puppet.override(:environments => Puppet::Environments::Static.new(env)) do
            expect(node_indirection.find(request).environment).to eq(env)
          end
        end

        it "should prefer the node's environment to the parent's" do
          child_env = Puppet::Node::Environment.create(:child, [])
          @entry[:parent] = "parent"
          @entry[:environment] = "child"

          @parent[:environment] = "parent"

          Puppet::Node::Facts.indirection.stubs(:find).with(nodename, :environment => child_env).returns(facts)

          Puppet.override(:environments => Puppet::Environments::Static.new(child_env)) do

            expect(node_indirection.find(request).environment).to eq(child_env)
          end
        end

        it "should recursively look up parent information" do
          @entry[:parent] = "parent"
          @entry[:parameters]["one"] = "two"

          @parent[:parent] = "parent_parent"
          @parent[:parameters]["three"] = "four"

          @parent_parent[:parameters]["five"] = "six"

          expect(node_indirection.find(request).parameters).to include("one" => "two", "three" => "four", "five" => "six")
        end

        it "should not allow loops in parent declarations" do
          @entry[:parent] = "parent"
          @parent[:parent] = nodename
          expect { node_indirection.find(request) }.to raise_error(ArgumentError)
        end
      end
    end
  end

  describe "when searching for multiple nodes" do
    let(:options) { {:environment => environment} }
    let(:request) { Puppet::Indirector::Request.new(:node, :find, nodename, nil, options) }

    before :each do
      Puppet::Node::Facts.indirection.stubs(:terminus_class).returns :yaml
    end

    it "should find all nodes if no arguments are provided" do
      node_indirection.expects(:ldapsearch).with("(objectclass=puppetClient)")
      # LAK:NOTE The search method requires an essentially bogus key.  It's
      # an API problem that I don't really know how to fix.
      node_indirection.search request
    end

    describe "and a class is specified" do
      it "should find all nodes that are members of that class" do
        node_indirection.expects(:ldapsearch).with("(&(objectclass=puppetClient)(puppetclass=one))")

        options[:class] = "one"
        node_indirection.search request
      end
    end

    describe "multiple classes are specified" do
      it "should find all nodes that are members of all classes" do
        node_indirection.expects(:ldapsearch).with("(&(objectclass=puppetClient)(puppetclass=one)(puppetclass=two))")
        options[:class] = %w{one two}
        node_indirection.search request
      end
    end

    it "should process each found entry" do
      # .yields can't be used to yield multiple values :/
      node_indirection.expects(:ldapsearch).yields("one")
      node_indirection.expects(:entry2hash).with("one",nil).returns(:name => nodename)
      node_indirection.search request
    end

    it "should return a node for each processed entry with the name from the entry" do
      node_indirection.expects(:ldapsearch).yields("whatever")
      node_indirection.expects(:entry2hash).with("whatever",nil).returns(:name => nodename)
      result = node_indirection.search(request)
      expect(result[0]).to be_instance_of(Puppet::Node)
      expect(result[0].name).to eq(nodename)
    end

    it "should merge each node's facts" do
      node_indirection.stubs(:ldapsearch).yields("one")
      node_indirection.stubs(:entry2hash).with("one",nil).returns(:name => nodename)
      expect(node_indirection.search(request)[0].parameters).to include(fact_values)
    end

    it "should pass the request's fqdn option to entry2hash" do
      options[:fqdn] = :hello
      node_indirection.stubs(:ldapsearch).yields("one")
      node_indirection.expects(:entry2hash).with("one",:hello).returns(:name => nodename)
      node_indirection.search(request)
    end
  end

  describe Puppet::Node::Ldap, " when developing the search query" do
    it "should return the value of the :ldapclassattrs split on commas as the class attributes" do
      Puppet[:ldapclassattrs] = "one,two"
      expect(node_indirection.class_attributes).to eq(%w{one two})
    end

    it "should return nil as the parent attribute if the :ldapparentattr is set to an empty string" do
      Puppet[:ldapparentattr] = ""
      expect(node_indirection.parent_attribute).to be_nil
    end

    it "should return the value of the :ldapparentattr as the parent attribute" do
      Puppet[:ldapparentattr] = "pere"
      expect(node_indirection.parent_attribute).to eq("pere")
    end

    it "should use the value of the :ldapstring as the search filter" do
      Puppet[:ldapstring] = "mystring"
      expect(node_indirection.search_filter("testing")).to eq("mystring")
    end

    it "should replace '%s' with the node name in the search filter if it is present" do
      Puppet[:ldapstring] = "my%sstring"
      expect(node_indirection.search_filter("testing")).to eq("mytestingstring")
    end

    it "should not modify the global :ldapstring when replacing '%s' in the search filter" do
      filter = mock 'filter'
      filter.expects(:include?).with("%s").returns(true)
      filter.expects(:gsub).with("%s", "testing").returns("mynewstring")
      Puppet[:ldapstring] = filter
      expect(node_indirection.search_filter("testing")).to eq("mynewstring")
    end
  end

  describe Puppet::Node::Ldap, " when deciding attributes to search for" do
    it "should use 'nil' if the :ldapattrs setting is 'all'" do
      Puppet[:ldapattrs] = "all"
      expect(node_indirection.search_attributes).to be_nil
    end

    it "should split the value of :ldapattrs on commas and use the result as the attribute list" do
      Puppet[:ldapattrs] = "one,two"
      node_indirection.stubs(:class_attributes).returns([])
      node_indirection.stubs(:parent_attribute).returns(nil)
      expect(node_indirection.search_attributes).to eq(%w{one two})
    end

    it "should add the class attributes to the search attributes if not returning all attributes" do
      Puppet[:ldapattrs] = "one,two"
      node_indirection.stubs(:class_attributes).returns(%w{three four})
      node_indirection.stubs(:parent_attribute).returns(nil)
      # Sort them so i don't have to care about return order
      expect(node_indirection.search_attributes.sort).to eq(%w{one two three four}.sort)
    end

    it "should add the parent attribute to the search attributes if not returning all attributes" do
      Puppet[:ldapattrs] = "one,two"
      node_indirection.stubs(:class_attributes).returns([])
      node_indirection.stubs(:parent_attribute).returns("parent")
      expect(node_indirection.search_attributes.sort).to eq(%w{one two parent}.sort)
    end

    it "should not add nil parent attributes to the search attributes" do
      Puppet[:ldapattrs] = "one,two"
      node_indirection.stubs(:class_attributes).returns([])
      node_indirection.stubs(:parent_attribute).returns(nil)
      expect(node_indirection.search_attributes).to eq(%w{one two})
    end
  end
end
