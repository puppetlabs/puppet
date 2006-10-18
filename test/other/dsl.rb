#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppet/dsl'
require 'puppet/autoload'
require 'puppettest'

class TestDSL < Test::Unit::TestCase
	include PuppetTest
	include Puppet::DSL

    def teardown
        Puppet::Aspect.clear
    end

    def test_aspect
        a = nil
        assert_nothing_raised do
            a = aspect :yaytest do
            end
        end

        assert_equal(a, Puppet::Aspect[:yaytest])

        # Now make a child aspect
        b = nil
        assert_nothing_raised do
            b = aspect :child, :inherits => :yaytest do
            end
        end

        assert(b.child_of?(a), "Parentage not set up correctly")
        assert(b.child_of?(:yaytest), "Parentage not set up for symbols")

        # Now make another subclass
        c = nil
        assert_nothing_raised do
            c = aspect :kid, :inherits => :child do
            end
        end

        assert(c.child_of?(b), "Parentage not set up correctly")
        assert(c.child_of?(a), "Parentage is not inherited")

        # Lastly, make a separate aspect
        x = nil
        assert_nothing_raised do
            x = aspect :other do
            end
        end

        assert(! x.child_of?(a), "Parentage came from nowhere")
        assert(! x.child_of?(b), "Parentage came from nowhere")
        assert(! x.child_of?(c), "Parentage came from nowhere")

        # Make sure we can specify the name or the aspect
        y = nil
        assert_nothing_raised do
            x = aspect :naming, :inherits => a do
            end
        end
        assert(x.child_of?(a), "Parentage not set up correctly")

        # And make sure the parent must exist
        z = nil
        assert_raise(RuntimeError) do
            z = aspect :noparent, :inherits => :nosuchaspect do
            end
        end
        assert(x.child_of?(a), "Parentage not set up correctly")
    end

    def test_evaluate
        parent = child = nil
        parenteval = childeval = nil
        
        assert_nothing_raised do
            parent = aspect :parent do
                if parenteval
                    raise "parent already evaluated"
                end
                parenteval = true
            end

            child = aspect :child, :inherits => parent do
                if childeval
                    raise "child already evaluated"
                end
                childeval = true
            end
        end

        assert_nothing_raised do
            parent.evaluate()
        end

        assert(parenteval, "Parent was not evaluated")
        assert(parent.evaluated?, "parent was not considered evaluated")

        # Make sure evaluating twice silently does nothing
        assert_nothing_raised do
            parent.evaluate()
        end

        # Now evaluate the child
        assert_nothing_raised do
            child.evaluate
        end

        assert(childeval, "child was not evaluated")
        assert(child.evaluated?, "child was not considered evaluated")

        # Now reset them both
        parenteval = childeval = nil
        parent.evaluated = false
        child.evaluated = false

        # evaluate the child
        assert_nothing_raised do
            child.evaluate
        end

        # and make sure both get evaluated
        assert(parenteval, "Parent was not evaluated")
        assert(parent.evaluated?, "parent was not considered evaluated")
        assert(childeval, "child was not evaluated")
        assert(child.evaluated?, "child was not considered evaluated")
    end

    def test_acquire
        evalled = false
        a = aspect :test do
            evalled = true
        end

        assert_nothing_raised do
            acquire :test
        end

        assert(evalled, "Did not evaluate aspect")

        assert_nothing_raised do
            acquire :test
        end
    end

    def test_newresource
        filetype = Puppet::Type.type(:file)
        path = tempfile()

        a = aspect :testing

        resource = nil
        assert_nothing_raised do
            resource = a.newresource filetype, path,
                :content => "yay", :mode => "640"
        end

        assert_instance_of(Puppet::Parser::Resource, resource)

        assert_equal("yay", resource[:content])
        assert_equal("640", resource[:mode])
        assert_equal(:testing, resource.source.name)

        # Now try exporting our aspect
        assert_nothing_raised do
            a.evaluate
        end

        result = nil
        assert_nothing_raised do
            result = a.export
        end

        assert_equal([resource], result)

        # Then try the DSL export
        assert_nothing_raised do
            result = export
        end

        assert_instance_of(Puppet::TransBucket, result)

        # And just for kicks, test applying everything
        assert_nothing_raised do
            apply()
        end

        assert(FileTest.exists?(path), "File did not get created")
        assert_equal("yay", File.read(path))
    end

    def test_typemethods
        filetype = Puppet::Type.type(:file)
        path = tempfile()

        a = aspect :testing

        Puppet::Type.eachtype do |type|
            assert(a.respond_to?(type.name),
                "Aspects do not have a %s method" % type.name)
        end

        file = nil
        assert_nothing_raised do
            file = a.file path,
                :content => "yay", :mode => "640"
        end

        assert_instance_of(Puppet::Parser::Resource, file)
    end
end

# $Id$
