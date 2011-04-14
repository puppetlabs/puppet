#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/indirector/node/ldap'

describe Puppet::Node::Ldap do
  describe "when searching for a single node" do
    before :each do
      @searcher = Puppet::Node::Ldap.new

      @name = "mynode.domain.com"
      @node = stub 'node', :name => @name, :name= => nil
      @node.stub_everything

      Puppet::Node.stubs(:new).returns(@node)

      @request = stub 'request', :key => @name
    end

    it "should convert the hostname into a search filter" do
      entry = stub 'entry', :dn => 'cn=mynode.domain.com,ou=hosts,dc=madstop,dc=com', :vals => %w{}, :to_hash => {}
      @searcher.expects(:ldapsearch).with("(&(objectclass=puppetClient)(cn=#{@name}))").yields entry
      @searcher.name2hash(@name)
    end

    it "should convert any found entry into a hash" do
      entry = stub 'entry', :dn => 'cn=mynode.domain.com,ou=hosts,dc=madstop,dc=com', :vals => %w{}, :to_hash => {}
      @searcher.expects(:ldapsearch).with("(&(objectclass=puppetClient)(cn=#{@name}))").yields entry
      myhash = {"myhash" => true}
      @searcher.expects(:entry2hash).with(entry).returns myhash
      @searcher.name2hash(@name).should == myhash
    end

    # This heavily tests our entry2hash method, so we don't have to stub out the stupid entry information any more.
    describe "when an ldap entry is found" do
      before do
        @entry = stub 'entry', :dn => 'cn=mynode,ou=hosts,dc=madstop,dc=com', :vals => %w{}, :to_hash => {}
        @searcher.stubs(:ldapsearch).yields @entry
      end

      it "should convert the entry to a hash" do
        @searcher.entry2hash(@entry).should be_instance_of(Hash)
      end

      it "should add the entry's common name to the hash if fqdn if false" do
        @searcher.entry2hash(@entry,fqdn = false)[:name].should == "mynode"
      end

      it "should add the entry's fqdn name to the hash if fqdn if true" do
        @searcher.entry2hash(@entry,fqdn = true)[:name].should == "mynode.madstop.com"
      end

      it "should add all of the entry's classes to the hash" do
        @entry.stubs(:vals).with("puppetclass").returns %w{one two}
        @searcher.entry2hash(@entry)[:classes].should == %w{one two}
      end

      it "should deduplicate class values" do
        @entry.stubs(:to_hash).returns({})
        @searcher.stubs(:class_attributes).returns(%w{one two})
        @entry.stubs(:vals).with("one").returns(%w{a b})
        @entry.stubs(:vals).with("two").returns(%w{b c})
        @searcher.entry2hash(@entry)[:classes].should == %w{a b c}
      end

      it "should add the entry's environment to the hash" do
        @entry.stubs(:to_hash).returns("environment" => %w{production})
        @searcher.entry2hash(@entry)[:environment].should == "production"
      end

      it "should add all stacked parameters as parameters in the hash" do
        @entry.stubs(:vals).with("puppetvar").returns(%w{one=two three=four})
        result = @searcher.entry2hash(@entry)
        result[:parameters]["one"].should == "two"
        result[:parameters]["three"].should == "four"
      end

      it "should not add the stacked parameter as a normal parameter" do
        @entry.stubs(:vals).with("puppetvar").returns(%w{one=two three=four})
        @entry.stubs(:to_hash).returns("puppetvar" => %w{one=two three=four})
        @searcher.entry2hash(@entry)[:parameters]["puppetvar"].should be_nil
      end

      it "should add all other attributes as parameters in the hash" do
        @entry.stubs(:to_hash).returns("foo" => %w{one two})
        @searcher.entry2hash(@entry)[:parameters]["foo"].should == %w{one two}
      end

      it "should return single-value parameters as strings, not arrays" do
        @entry.stubs(:to_hash).returns("foo" => %w{one})
        @searcher.entry2hash(@entry)[:parameters]["foo"].should == "one"
      end

      it "should convert 'true' values to the boolean 'true'" do
        @entry.stubs(:to_hash).returns({"one" => ["true"]})
        @searcher.entry2hash(@entry)[:parameters]["one"].should == true
      end

      it "should convert 'false' values to the boolean 'false'" do
        @entry.stubs(:to_hash).returns({"one" => ["false"]})
        @searcher.entry2hash(@entry)[:parameters]["one"].should == false
      end

      it "should convert 'true' values to the boolean 'true' inside an array" do
        @entry.stubs(:to_hash).returns({"one" => ["true", "other"]})
        @searcher.entry2hash(@entry)[:parameters]["one"].should == [true, "other"]
      end

      it "should convert 'false' values to the boolean 'false' inside an array" do
        @entry.stubs(:to_hash).returns({"one" => ["false", "other"]})
        @searcher.entry2hash(@entry)[:parameters]["one"].should == [false, "other"]
      end

      it "should add the parent's name if present" do
        @entry.stubs(:vals).with("parentnode").returns(%w{foo})
        @searcher.entry2hash(@entry)[:parent].should == "foo"
      end

      it "should fail if more than one parent is specified" do
        @entry.stubs(:vals).with("parentnode").returns(%w{foo})
        @searcher.entry2hash(@entry)[:parent].should == "foo"
      end
    end

    it "should search first for the provided key" do
      @searcher.expects(:name2hash).with("mynode.domain.com").returns({})
      @searcher.find(@request)
    end

    it "should search for the short version of the provided key if the key looks like a hostname and no results are found for the key itself" do
      @searcher.expects(:name2hash).with("mynode.domain.com").returns(nil)
      @searcher.expects(:name2hash).with("mynode").returns({})
      @searcher.find(@request)
    end

    it "should search for default information if no information can be found for the key" do
      @searcher.expects(:name2hash).with("mynode.domain.com").returns(nil)
      @searcher.expects(:name2hash).with("mynode").returns(nil)
      @searcher.expects(:name2hash).with("default").returns({})
      @searcher.find(@request)
    end

    it "should return nil if no results are found in ldap" do
      @searcher.stubs(:name2hash).returns nil
      @searcher.find(@request).should be_nil
    end

    it "should return a node object if results are found in ldap" do
      @searcher.stubs(:name2hash).returns({})
      @searcher.find(@request).should equal(@node)
    end

    describe "and node information is found in LDAP" do
      before do
        @result = {}
        @searcher.stubs(:name2hash).returns @result
      end

      it "should create the node with the correct name, even if it was found by a different name" do
        @searcher.expects(:name2hash).with("mynode.domain.com").returns nil
        @searcher.expects(:name2hash).with("mynode").returns @result

        Puppet::Node.expects(:new).with("mynode.domain.com").returns @node
        @searcher.find(@request)
      end

      it "should add any classes from ldap" do
        @result[:classes] = %w{a b c d}
        @node.expects(:classes=).with(%w{a b c d})
        @searcher.find(@request)
      end

      it "should add all entry attributes as node parameters" do
        @result[:parameters] = {"one" => "two", "three" => "four"}
        @node.expects(:parameters=).with("one" => "two", "three" => "four")
        @searcher.find(@request)
      end

      it "should set the node's environment to the environment of the results" do
        @result[:environment] = "test"
        @node.expects(:environment=).with("test")
        @searcher.find(@request)
      end

      it "should retain false parameter values" do
        @result[:parameters] = {}
        @result[:parameters]["one"] = false
        @node.expects(:parameters=).with("one" => false)
        @searcher.find(@request)
      end

      it "should merge the node's facts after the parameters from ldap are assigned" do
        # Make sure we've got data to start with, so the parameters are actually set.
        @result[:parameters] = {}
        @result[:parameters]["one"] = "yay"

        # A hackish way to enforce order.
        set = false
        @node.expects(:parameters=).with { |*args| set = true }
        @node.expects(:fact_merge).with { |*args| raise "Facts were merged before parameters were set" unless set; true }

        @searcher.find(@request)
      end

      describe "and a parent node is specified" do
        before do
          @entry = {:classes => [], :parameters => {}}
          @parent = {:classes => [], :parameters => {}}
          @parent_parent = {:classes => [], :parameters => {}}

          @searcher.stubs(:name2hash).with(@name).returns(@entry)
          @searcher.stubs(:name2hash).with('parent').returns(@parent)
          @searcher.stubs(:name2hash).with('parent_parent').returns(@parent_parent)

          @searcher.stubs(:parent_attribute).returns(:parent)
        end

        it "should search for the parent node" do
          @entry[:parent] = "parent"
          @searcher.expects(:name2hash).with(@name).returns @entry
          @searcher.expects(:name2hash).with('parent').returns @parent

          @searcher.find(@request)
        end

        it "should fail if the parent cannot be found" do
          @entry[:parent] = "parent"

          @searcher.expects(:name2hash).with('parent').returns nil

          proc { @searcher.find(@request) }.should raise_error(Puppet::Error)
        end

        it "should add any parent classes to the node's classes" do
          @entry[:parent] = "parent"
          @entry[:classes] = %w{a b}

          @parent[:classes] = %w{c d}

          @node.expects(:classes=).with(%w{a b c d})
          @searcher.find(@request)
        end

        it "should add any parent parameters to the node's parameters" do
          @entry[:parent] = "parent"
          @entry[:parameters]["one"] = "two"

          @parent[:parameters]["three"] = "four"

          @node.expects(:parameters=).with("one" => "two", "three" => "four")
          @searcher.find(@request)
        end

        it "should prefer node parameters over parent parameters" do
          @entry[:parent] = "parent"
          @entry[:parameters]["one"] = "two"

          @parent[:parameters]["one"] = "three"

          @node.expects(:parameters=).with("one" => "two")
          @searcher.find(@request)
        end

        it "should use the parent's environment if the node has none" do
          @entry[:parent] = "parent"

          @parent[:environment] = "parent"

          @node.stubs(:parameters=)
          @node.expects(:environment=).with("parent")
          @searcher.find(@request)
        end

        it "should prefer the node's environment to the parent's" do
          @entry[:parent] = "parent"
          @entry[:environment] = "child"

          @parent[:environment] = "parent"

          @node.stubs(:parameters=)
          @node.expects(:environment=).with("child")
          @searcher.find(@request)
        end

        it "should recursively look up parent information" do
          @entry[:parent] = "parent"
          @entry[:parameters]["one"] = "two"

          @parent[:parent] = "parent_parent"
          @parent[:parameters]["three"] = "four"

          @parent_parent[:parameters]["five"] = "six"

          @node.expects(:parameters=).with("one" => "two", "three" => "four", "five" => "six")
          @searcher.find(@request)
        end

        it "should not allow loops in parent declarations" do
          @entry[:parent] = "parent"
          @parent[:parent] = @name
          proc { @searcher.find(@request) }.should raise_error(ArgumentError)
        end
      end
    end
  end

  describe "when searching for multiple nodes" do
    before :each do
      @searcher = Puppet::Node::Ldap.new
      @options = {}
      @request = stub 'request', :key => "foo", :options => @options

      Puppet::Node::Facts.indirection.stubs(:terminus_class).returns :yaml
    end

    it "should find all nodes if no arguments are provided" do
      @searcher.expects(:ldapsearch).with("(objectclass=puppetClient)")
      # LAK:NOTE The search method requires an essentially bogus key.  It's
      # an API problem that I don't really know how to fix.
      @searcher.search @request
    end

    describe "and a class is specified" do
      it "should find all nodes that are members of that class" do
        @searcher.expects(:ldapsearch).with("(&(objectclass=puppetClient)(puppetclass=one))")

        @options[:class] = "one"
        @searcher.search @request
      end
    end

    describe "multiple classes are specified" do
      it "should find all nodes that are members of all classes" do
        @searcher.expects(:ldapsearch).with("(&(objectclass=puppetClient)(puppetclass=one)(puppetclass=two))")
        @options[:class] = %w{one two}
        @searcher.search @request
      end
    end

    it "should process each found entry" do
      # .yields can't be used to yield multiple values :/
      @searcher.expects(:ldapsearch).yields("one")
      @searcher.expects(:entry2hash).with("one",nil).returns(:name => "foo")
      @searcher.search @request
    end

    it "should return a node for each processed entry with the name from the entry" do
      @searcher.expects(:ldapsearch).yields("whatever")
      @searcher.expects(:entry2hash).with("whatever",nil).returns(:name => "foo")
      result = @searcher.search(@request)
      result[0].should be_instance_of(Puppet::Node)
      result[0].name.should == "foo"
    end

    it "should merge each node's facts" do
      node = mock 'node'
      Puppet::Node.expects(:new).with("foo").returns node
      node.expects(:fact_merge)
      @searcher.stubs(:ldapsearch).yields("one")
      @searcher.stubs(:entry2hash).with("one",nil).returns(:name => "foo")
      @searcher.search(@request)
    end

    it "should pass the request's fqdn option to entry2hash" do
      node = mock 'node'
      @options[:fqdn] = :hello
      Puppet::Node.stubs(:new).with("foo").returns node
      node.stubs(:fact_merge)
      @searcher.stubs(:ldapsearch).yields("one")
      @searcher.expects(:entry2hash).with("one",:hello).returns(:name => "foo")
      @searcher.search(@request)
    end
  end
end

describe Puppet::Node::Ldap, " when developing the search query" do
  before do
    @searcher = Puppet::Node::Ldap.new
  end

  it "should return the value of the :ldapclassattrs split on commas as the class attributes" do
    Puppet.stubs(:[]).with(:ldapclassattrs).returns("one,two")
    @searcher.class_attributes.should == %w{one two}
  end

  it "should return nil as the parent attribute if the :ldapparentattr is set to an empty string" do
    Puppet.stubs(:[]).with(:ldapparentattr).returns("")
    @searcher.parent_attribute.should be_nil
  end

  it "should return the value of the :ldapparentattr as the parent attribute" do
    Puppet.stubs(:[]).with(:ldapparentattr).returns("pere")
    @searcher.parent_attribute.should == "pere"
  end

  it "should use the value of the :ldapstring as the search filter" do
    Puppet.stubs(:[]).with(:ldapstring).returns("mystring")
    @searcher.search_filter("testing").should == "mystring"
  end

  it "should replace '%s' with the node name in the search filter if it is present" do
    Puppet.stubs(:[]).with(:ldapstring).returns("my%sstring")
    @searcher.search_filter("testing").should == "mytestingstring"
  end

  it "should not modify the global :ldapstring when replacing '%s' in the search filter" do
    filter = mock 'filter'
    filter.expects(:include?).with("%s").returns(true)
    filter.expects(:gsub).with("%s", "testing").returns("mynewstring")
    Puppet.stubs(:[]).with(:ldapstring).returns(filter)
    @searcher.search_filter("testing").should == "mynewstring"
  end
end

describe Puppet::Node::Ldap, " when deciding attributes to search for" do
  before do
    @searcher = Puppet::Node::Ldap.new
  end

  it "should use 'nil' if the :ldapattrs setting is 'all'" do
    Puppet.stubs(:[]).with(:ldapattrs).returns("all")
    @searcher.search_attributes.should be_nil
  end

  it "should split the value of :ldapattrs on commas and use the result as the attribute list" do
    Puppet.stubs(:[]).with(:ldapattrs).returns("one,two")
    @searcher.stubs(:class_attributes).returns([])
    @searcher.stubs(:parent_attribute).returns(nil)
    @searcher.search_attributes.should == %w{one two}
  end

  it "should add the class attributes to the search attributes if not returning all attributes" do
    Puppet.stubs(:[]).with(:ldapattrs).returns("one,two")
    @searcher.stubs(:class_attributes).returns(%w{three four})
    @searcher.stubs(:parent_attribute).returns(nil)
    # Sort them so i don't have to care about return order
    @searcher.search_attributes.sort.should == %w{one two three four}.sort
  end

  it "should add the parent attribute to the search attributes if not returning all attributes" do
    Puppet.stubs(:[]).with(:ldapattrs).returns("one,two")
    @searcher.stubs(:class_attributes).returns([])
    @searcher.stubs(:parent_attribute).returns("parent")
    @searcher.search_attributes.sort.should == %w{one two parent}.sort
  end

  it "should not add nil parent attributes to the search attributes" do
    Puppet.stubs(:[]).with(:ldapattrs).returns("one,two")
    @searcher.stubs(:class_attributes).returns([])
    @searcher.stubs(:parent_attribute).returns(nil)
    @searcher.search_attributes.should == %w{one two}
  end
end
