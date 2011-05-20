#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/puppettest')

require 'mocha'
require 'puppettest'
require 'puppettest/parsertesting'
require 'puppettest/resourcetesting'

# so, what kind of things do we want to test?

# we don't need to test function, since we're confident in the
# library tests.  We do, however, need to test how things are actually
# working in the language.

# so really, we want to do things like test that our ast is correct
# and test whether we've got things in the right scopes

class TestScope < Test::Unit::TestCase
  include PuppetTest::ParserTesting
  include PuppetTest::ResourceTesting

  def setup
    Puppet::Node::Environment.clear
    super
  end

  def to_ary(hash)
    hash.collect { |key,value|
      [key,value]
    }
  end

  def test_variables
    config = mkcompiler
    topscope = config.topscope
    midscope = config.newscope(topscope)
    botscope = config.newscope(midscope)

    scopes = {:top => topscope, :mid => midscope, :bot => botscope}

    # Set a variable in the top and make sure all three can get it
    topscope.setvar("first", "topval")
    scopes.each do |name, scope|
      assert_equal("topval", scope.lookupvar("first"), "Could not find var in #{name}")
    end

    # Now set a var in the midscope and make sure the mid and bottom can see it but not the top
    midscope.setvar("second", "midval")
    assert_equal(:undefined, scopes[:top].lookupvar("second"), "Found child var in top scope")
    [:mid, :bot].each do |name|
      assert_equal("midval", scopes[name].lookupvar("second"), "Could not find var in #{name}")
    end

    # And set something in the bottom, and make sure we only find it there.
    botscope.setvar("third", "botval")
    [:top, :mid].each do |name|
      assert_equal(:undefined, scopes[name].lookupvar("third"), "Found child var in top scope")
    end
    assert_equal("botval", scopes[:bot].lookupvar("third"), "Could not find var in bottom scope")


    # Test that the scopes convert to hash structures correctly.
    # For topscope recursive vs non-recursive should be identical
    assert_equal(topscope.to_hash(false), topscope.to_hash(true),
      "Recursive and non-recursive hash is identical for topscope")

    # Check the variable we expect is present.
    assert_equal({"first" => "topval"}, topscope.to_hash, "topscope returns the expected hash of variables")

    # Now, check that midscope does the right thing in all cases.

      assert_equal(
        {"second" => "midval"},
          midscope.to_hash(false),

          "midscope non-recursive hash contains only midscope variable")

          assert_equal(
            {"first" => "topval", "second" => "midval"},
          midscope.to_hash(true),

          "midscope recursive hash contains topscope variable also")

    # Finally, check the ability to shadow symbols by adding a shadow to
    # bottomscope, then checking that we see the right stuff.
    botscope.setvar("first", "shadowval")

      assert_equal(
        {"third" => "botval", "first" => "shadowval"},
          botscope.to_hash(false),

          "botscope has the right non-recursive hash")

          assert_equal(
            {"third" => "botval", "first" => "shadowval", "second" => "midval"},
          botscope.to_hash(true),

          "botscope values shadow parent scope values")
  end

  def test_declarative
    # set to declarative
    top = mkscope
    sub = mkscope(:parent => top)

    assert_nothing_raised {
      top.setvar("test","value")
    }
    assert_raise(Puppet::ParseError) {
      top.setvar("test","other")
    }
    assert_nothing_raised {
      sub.setvar("test","later")
    }
    assert_raise(Puppet::ParseError) {
      top.setvar("test","yeehaw")
    }
  end

  def test_parent
    config = mkcompiler
    top = config.topscope

    # Make a subscope
    sub = config.newscope(top)

    assert_equal(top, sub.parent, "Did not find parent scope correctly")
    assert_equal(top, sub.parent, "Did not find parent scope on second call")
  end

  # Make sure we know what we consider to be truth.
  def test_truth

    assert_equal(
      true, Puppet::Parser::Scope.true?("a string"),

      "Strings not considered true")

        assert_equal(
          true, Puppet::Parser::Scope.true?(true),

      "True considered true")

        assert_equal(
          false, Puppet::Parser::Scope.true?(""),

      "Empty strings considered true")

        assert_equal(
          false, Puppet::Parser::Scope.true?(false),

      "false considered true")

        assert_equal(
          false, Puppet::Parser::Scope.true?(:undef),

      "undef considered true")
  end

  def test_virtual_definitions_do_not_get_evaluated
    parser = mkparser
    config = mkcompiler

    # Create a default source
    parser.known_resource_types.add Puppet::Resource::Type.new(:hostclass, "")
    config.topscope.source = parser.known_resource_types.hostclass("")

    # And a scope resource
    scope_res = Puppet::Parser::Resource.new(:file, "/file", :scope => config.topscope)
    config.topscope.resource = scope_res

    args = AST::ASTArray.new(
      :children => [nameobj("arg")]
    )

    # Create a top-level define
    parser.known_resource_types.add Puppet::Resource::Type.new(:definition, "one", :arguments => [%w{arg}],
      :code => AST::ASTArray.new(
        :children => [
          resourcedef("file", "/tmp", {"owner" => varref("arg")})
        ]
      ))

    # create a resource that calls our third define
    obj = resourcedef("one", "boo", {"arg" => "parentfoo"})

    # And mark it as virtual
    obj.virtual = true

    # And then evaluate it
    obj.evaluate config.topscope

    # And run the loop.
    config.send(:evaluate_generators)

    %w{File}.each do |type|
      objects = config.resources.find_all { |r| r.type == type and r.virtual }

      assert(objects.empty?, "Virtual define got evaluated")
    end
  end

  if defined? ::ActiveRecord
  # Verify that we can both store and collect an object in the same
  # run, whether it's in the same scope as a collection or a different
  # scope.
  def test_storeandcollect
    catalog_cache_class = Puppet::Resource::Catalog.indirection.cache_class
    facts_cache_class = Puppet::Node::Facts.indirection.cache_class
    node_cache_class = Puppet::Node.indirection.cache_class
    Puppet[:storeconfigs] = true
    Puppet::Rails.init
    sleep 1
    children = []
    Puppet[:code] = "
class yay {
  @@host { myhost: ip => \"192.168.0.2\" }
}
include yay
@@host { puppet: ip => \"192.168.0.3\" }
Host <<||>>"

  config = nil
  # We run it twice because we want to make sure there's no conflict
  # if we pull it up from the database.
  node = mknode
  node.merge "hostname" => node.name
  2.times { |i|
    catalog = Puppet::Parser::Compiler.new(node).compile
    assert_instance_of(Puppet::Parser::Resource, catalog.resource(:host, "puppet"))
    assert_instance_of(Puppet::Parser::Resource, catalog.resource(:host, "myhost"))
    }
  ensure
    Puppet[:storeconfigs] = false
    Puppet::Resource::Catalog.indirection.cache_class =  catalog_cache_class
    Puppet::Node::Facts.indirection.cache_class = facts_cache_class
    Puppet::Node.indirection.cache_class = node_cache_class
  end
  else
    $stderr.puts "No ActiveRecord -- skipping collection tests"
  end

  def test_namespaces
    scope = mkscope


      assert_equal(
        [""], scope.namespaces,

      "Started out with incorrect namespaces")
    assert_nothing_raised { scope.add_namespace("fun::test") }
    assert_equal(["fun::test"], scope.namespaces, "Did not add namespace correctly")
    assert_nothing_raised { scope.add_namespace("yay::test") }
    assert_equal(["fun::test", "yay::test"], scope.namespaces, "Did not add extra namespace correctly")
  end

  # #629 - undef should be "" or :undef
  def test_lookupvar_with_undef
    scope = mkscope

    scope.setvar("testing", :undef)
    assert_equal(:undef, scope.lookupvar("testing"), "undef was not returned as :undef")
  end
end

