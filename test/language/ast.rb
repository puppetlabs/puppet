#!/usr/bin/env ruby -I../lib -I../../lib

require 'puppet'
require 'puppet/rails'
require 'puppet/parser/interpreter'
require 'puppet/parser/parser'
require 'puppet/client'
require 'puppettest'
require 'puppettest/resourcetesting'
require 'puppettest/parsertesting'
require 'puppettest/railstesting'

class TestAST < Test::Unit::TestCase
    include PuppetTest::RailsTesting
    include PuppetTest::ParserTesting
    include PuppetTest::ResourceTesting

    # A fake class that we can use for testing evaluation.
    class FakeAST
        attr_writer :evaluate

        def evaluate(*args)
            return @evaluate
        end

        def initialize(val = nil)
            if val
                @evaluate = val
            end
        end

        def safeevaluate(*args)
            evaluate()
        end
    end

    if defined? ActiveRecord
    # Verify that our collection stuff works.
    def test_collection
        collectable = []
        non = []
        # First put some objects into the database.
        bucket = mk_transtree do |object, depth, width|
            # and mark some of them collectable
            if width % 2 == 1
                object.collectable = true
                collectable << object
            else
                non << object
            end
        end

        # Now collect our facts
        facts = {}
        Facter.each do |fact, value| facts[fact] = value end

        assert_nothing_raised {
            Puppet::Rails.init
        }

        # Now try storing our crap
        assert_nothing_raised {
            host = Puppet::Rails::Host.store(
                :objects => bucket,
                :facts => facts,
                :host => facts["hostname"]
            )
        }

        # Now create an ast tree that collects that.  They should all be files.
        coll = nil
        assert_nothing_raised {
            coll = AST::Collection.new(
                :type => nameobj("file")
            )
        }

        top = nil
        assert_nothing_raised("Could not create top object") {
            top = AST::ASTArray.new(
                :children => [coll]
            )
        }

        objects = nil
        assert_nothing_raised("Could not evaluate") {
            scope = mkscope
            objects = scope.evaluate(:ast => top).flatten
        }

        assert(objects.length > 0, "Did not receive any collected objects")
    end
    else
        $stderr.puts "No ActiveRecord -- skipping collection tests"
    end

    def test_if
        astif = nil
        astelse = nil
        fakeelse = FakeAST.new(:else)
        faketest = FakeAST.new(true)
        fakeif = FakeAST.new(:if)

        assert_nothing_raised {
            astelse = AST::Else.new(:statements => fakeelse)
        }
        assert_nothing_raised {
            astif = AST::IfStatement.new(
                :test => faketest,
                :statements => fakeif,
                :else => astelse
            )
        }

        # We initialized it to true, so we should get that first
        ret = nil
        assert_nothing_raised {
            ret = astif.evaluate(:scope => "yay")
        }
        assert_equal(:if, ret)

        # Now set it to false and check that
        faketest.evaluate = false
        assert_nothing_raised {
            ret = astif.evaluate(:scope => "yay")
        }
        assert_equal(:else, ret)
    end

    # Make sure our override object behaves "correctly"
    def test_override
        interp, scope, source = mkclassframing

        ref = nil
        assert_nothing_raised do
            ref = resourceoverride("resource", "yaytest", "one" => "yay", "two" => "boo")
        end

        ret = nil
        assert_nothing_raised do
            ret = ref.evaluate :scope => scope
        end

        assert_instance_of(Puppet::Parser::Resource, ret)

        assert(ret.override?, "Resource was not an override resource")

        assert(scope.overridetable[ret.ref].include?(ret),
            "Was not stored in the override table")
    end

    # make sure our resourcedefaults ast object works correctly.
    def test_resourcedefaults
        interp, scope, source = mkclassframing

        # Now make some defaults for files
        args = {:source => "/yay/ness", :group => "yayness"}
        assert_nothing_raised do
            obj = defaultobj "file", args
            obj.evaluate :scope => scope
        end

        hash = nil
        assert_nothing_raised do
            hash = scope.lookupdefaults("file")
        end

        hash.each do |name, value|
            assert_instance_of(Symbol, name) # params always convert
            assert_instance_of(Puppet::Parser::Resource::Param, value)
        end

        args.each do |name, value|
            assert(hash[name], "Did not get default %s" % name)
            assert_equal(value, hash[name].value)
        end
    end

    def test_hostclass
        interp, scope, source = mkclassframing

        # Create the class we're testing, first with no parent
        klass = interp.newclass "first",
            :code => AST::ASTArray.new(
                :children => [resourcedef("file", "/tmp",
                        "owner" => "nobody", "mode" => "755")]
            )

        assert_nothing_raised do
            klass.evaluate(:scope => scope)
        end

        # Then try it again
        assert_nothing_raised do
            klass.evaluate(:scope => scope)
        end

        assert(scope.setclass?(klass), "Class was not considered evaluated")

        tmp = scope.findresource("file[/tmp]")
        assert(tmp, "Could not find file /tmp")
        assert_equal("nobody", tmp[:owner])
        assert_equal("755", tmp[:mode])

        # Now create a couple more classes.
        newbase = interp.newclass "newbase",
            :code => AST::ASTArray.new(
                :children => [resourcedef("file", "/tmp/other",
                        "owner" => "nobody", "mode" => "644")]
            )

        newsub = interp.newclass "newsub",
            :parent => "newbase",
            :code => AST::ASTArray.new(
                :children => [resourcedef("file", "/tmp/yay",
                        "owner" => "nobody", "mode" => "755"),
                    resourceoverride("file", "/tmp/other",
                            "owner" => "daemon")
                ]
            )

        # Override a different variable in the top scope.
        moresub = interp.newclass "moresub",
            :parent => "newbase",
            :code => AST::ASTArray.new(
                :children => [resourceoverride("file", "/tmp/other",
                            "mode" => "755")]
            )

        assert_nothing_raised do
            newsub.evaluate(:scope => scope)
        end

        assert_nothing_raised do
            moresub.evaluate(:scope => scope)
        end

        assert(scope.setclass?(newbase), "Did not eval newbase")
        assert(scope.setclass?(newsub), "Did not eval newsub")

        yay = scope.findresource("file[/tmp/yay]")
        assert(yay, "Did not find file /tmp/yay")
        assert_equal("nobody", yay[:owner])
        assert_equal("755", yay[:mode])

        other = scope.findresource("file[/tmp/other]")
        assert(other, "Did not find file /tmp/other")
        assert_equal("daemon", other[:owner])
        assert_equal("755", other[:mode])
    end

    def test_component
        interp, scope, source = mkclassframing

        # Create a new definition
        klass = interp.newdefine "yayness",
            :arguments => [["owner", stringobj("nobody")], %w{mode}],
            :code => AST::ASTArray.new(
                :children => [resourcedef("file", "/tmp/$name",
                        "owner" => varref("owner"), "mode" => varref("mode"))]
            )

        # Test validattr? a couple different ways
        [:owner, "owner", :schedule, "schedule"].each do |var|
            assert(klass.validattr?(var), "%s was not considered valid" % var.inspect)
        end

        [:random, "random"].each do |var|
            assert(! klass.validattr?(var), "%s was considered valid" % var.inspect)
        end
        # Now call it a couple of times
        # First try it without a required param
        assert_raise(Puppet::ParseError) do
            klass.evaluate(:scope => scope,
                :name => "bad",
                :arguments => {"owner" => "nobody"}
            )
        end

        # And make sure it didn't create the file
        assert_nil(scope.findresource("file[/tmp/bad]"),
            "Made file with invalid params")

        assert_nothing_raised do
            klass.evaluate(:scope => scope,
                :name => "first",
                :arguments => {"mode" => "755"}
            )
        end

        firstobj = scope.findresource("file[/tmp/first]")
        assert(firstobj, "Did not create /tmp/first obj")

        assert_equal("file", firstobj.type)
        assert_equal("/tmp/first", firstobj.title)
        assert_equal("nobody", firstobj[:owner])
        assert_equal("755", firstobj[:mode])

        # Make sure we can't evaluate it with the same args
        assert_raise(Puppet::ParseError) do
            klass.evaluate(:scope => scope,
                :name => "first",
                :arguments => {"mode" => "755"}
            )
        end

        # Now create another with different args
        assert_nothing_raised do
            klass.evaluate(:scope => scope,
                :name => "second",
                :arguments => {"mode" => "755", "owner" => "daemon"}
            )
        end

        secondobj = scope.findresource("file[/tmp/second]")
        assert(secondobj, "Did not create /tmp/second obj")

        assert_equal("file", secondobj.type)
        assert_equal("/tmp/second", secondobj.title)
        assert_equal("daemon", secondobj[:owner])
        assert_equal("755", secondobj[:mode])
    end

    def test_node
        interp = mkinterp
        scope = mkscope(:interp => interp)

        # Define a base node
        basenode = interp.newnode "basenode", :code => AST::ASTArray.new(:children => [
            resourcedef("file", "/tmp/base", "owner" => "root")
        ])

        # Now define a subnode
        nodes = interp.newnode ["mynode", "othernode"],
            :code => AST::ASTArray.new(:children => [
                resourcedef("file", "/tmp/mynode", "owner" => "root"),
                resourcedef("file", "/tmp/basenode", "owner" => "daemon")
        ])

        assert_instance_of(Array, nodes)

        # Make sure we can find them all.
        %w{mynode othernode}.each do |node|
            assert(interp.nodesearch_code(node), "Could not find %s" % node)
        end
        mynode = interp.nodesearch_code("mynode")

        # Now try evaluating the node
        assert_nothing_raised do
            mynode.evaluate :scope => scope
        end

        # Make sure that we can find each of the files
        myfile = scope.findresource "file[/tmp/mynode]"
        assert(myfile, "Could not find file from node")
        assert_equal("root", myfile[:owner])

        basefile = scope.findresource "file[/tmp/basenode]"
        assert(basefile, "Could not find file from base node")
        assert_equal("daemon", basefile[:owner])

        # Now make sure we can evaluate nodes with parents
        child = interp.newnode(%w{child}, :parent => "basenode").shift

        newscope = mkscope :interp => interp
        assert_nothing_raised do
            child.evaluate :scope => newscope
        end

        assert(newscope.findresource("file[/tmp/base]"),
            "Could not find base resource")
    end

    def test_collection
        interp = mkinterp
        scope = mkscope(:interp => interp)

        coll = nil
        assert_nothing_raised do
            coll = AST::Collection.new(:type => "file", :form => :virtual)
        end

        assert_instance_of(AST::Collection, coll)

        ret = nil
        assert_nothing_raised do
            ret = coll.evaluate :scope => scope
        end

        assert_instance_of(Puppet::Parser::Collector, ret)

        # Now make sure we get it back from the scope
        assert_equal([ret], scope.collections)
    end

    def test_virtual_collexp
        @interp, @scope, @source = mkclassframing

        # make a resource
        resource = mkresource(:type => "file", :title => "/tmp/testing",
            :params => {:owner => "root", :group => "bin", :mode => "644"})

        run_collection_queries(:virtual) do |string, result, query|
            code = nil
            assert_nothing_raised do
                str, code = query.evaluate :scope => @scope
            end

            assert_instance_of(Proc, code)
            assert_nothing_raised do
                assert_equal(result, code.call(resource),
                    "'#{string}' failed")
            end
        end
    end

    if defined? ActiveRecord::Base
    def test_exported_collexp
        railsinit
        Puppet[:storeconfigs] = true
        @interp, @scope, @source = mkclassframing

        # make a rails resource
        railsresource "file", "/tmp/testing", :owner => "root", :group => "bin",
            :mode => "644"

        run_collection_queries(:exported) do |string, result, query|
            code = nil
            str = nil

            # We don't support anything but the title in rails right now
            retval = nil
            bad = false
            # Figure out if the search is for anything rails will ignore
            string.scan(/(\w+) [!=]= \w+/) do |s|
                unless s[0] == "title"
                    bad = true
                    break
                end
            end

            # And if it is, make sure we throw an error.
            if bad
                assert_raise(Puppet::ParseError, "Evaluated '#{string}'") do
                    str, code = query.evaluate :scope => @scope
                end
                next
            else
                assert_nothing_raised("Could not evaluate '#{string}'") do
                    str, code = query.evaluate :scope => @scope
                end
            end
            assert_nothing_raised("Could not find resource") do
                retval = Puppet::Rails::RailsResource.find(:all,
                    :include => :rails_parameters,
                    :conditions => str) 
            end

            if result
                assert_equal(1, retval.length, "Did not find resource with '#{string}'")
                res = retval.shift

                assert_equal("file", res.restype)
                assert_equal("/tmp/testing", res.title)
            else
                assert_equal(0, retval.length, "found a resource with '#{string}'")
            end
        end
    end
    end

    def run_collection_queries(form)
        {true => [%{title == "/tmp/testing"}, %{(title == "/tmp/testing")},
            %{title == "/tmp/testing" and group == bin}, %{title == bin or group == bin},
            %{title == "/tmp/testing" or title == bin}, %{title == "/tmp/testing"},
            %{(title == "/tmp/testing" or title == bin) and group == bin}],
        false => [%{title == bin}, %{title == bin or (title == bin and group == bin)},
            %{title != "/tmp/testing"}, %{title != "/tmp/testing" and group != bin}]
        }.each do |res, ary|
            ary.each do |str|
                if form == :virtual
                    code = "File <| #{str} |>"
                else
                    code = "File <<| #{str} |>>"
                end
                parser = mkparser
                query = nil

                assert_nothing_raised("Could not parse '#{str}'") do
                    query = parser.parse(code)[0].query
                end

                yield str, res, query
            end
        end
    end
end

# $Id$
