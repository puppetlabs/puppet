#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppet/parser/interpreter'
require 'puppet/parser/parser'
require 'puppet/network/client'
require 'puppettest'
require 'puppettest/resourcetesting'

class TestLangFunctions < Test::Unit::TestCase
    include PuppetTest::ParserTesting
    include PuppetTest::ResourceTesting
    def test_functions
        assert_raise(Puppet::ParseError) do
            Puppet::Parser::AST::Function.new(
                :name => "fakefunction",
                :arguments => AST::ASTArray.new(
                    :children => [nameobj("avalue")]
                )
            )
        end

        assert_nothing_raised do
            Puppet::Parser::Functions.newfunction(:fakefunction, :type => :rvalue) do |input|
                return "output %s" % input[0]
            end
        end

        func = nil
        assert_nothing_raised do
            func = Puppet::Parser::AST::Function.new(
                :name => "fakefunction",
                :ftype => :rvalue,
                :arguments => AST::ASTArray.new(
                    :children => [nameobj("avalue")]
                )
            )
        end

        scope = mkscope
        val = nil
        assert_nothing_raised do
            val = func.evaluate(:scope => scope)
        end

        assert_equal("output avalue", val)
    end

    def test_taggedfunction
        scope = mkscope

        tag = "yayness"
        scope.tag(tag)

        {"yayness" => true, "booness" => false}.each do |tag, retval|
            func = taggedobj(tag, :rvalue)

            val = nil
            assert_nothing_raised do
                val = func.evaluate(:scope => scope)
            end

            assert_equal(retval, val, "'tagged' returned %s for %s" % [val, tag])
        end
    end

    def test_failfunction
        func = nil
        assert_nothing_raised do
            func = Puppet::Parser::AST::Function.new(
                :name => "fail",
                :ftype => :statement,
                :arguments => AST::ASTArray.new(
                    :children => [stringobj("this is a failure"),
                        stringobj("and another")]
                )
            )
        end

        scope = mkscope
        val = nil
        assert_raise(Puppet::ParseError) do
            val = func.evaluate(:scope => scope)
        end
    end

    def test_multipletemplates
        Dir.mkdir(Puppet[:templatedir])
        onep = File.join(Puppet[:templatedir], "one")
        twop = File.join(Puppet[:templatedir], "two")

        File.open(onep, "w") do |f|
            f.puts "template <%= one %>"
        end

        File.open(twop, "w") do |f|
            f.puts "template <%= two %>"
        end
        func = nil
        assert_nothing_raised do
            func = Puppet::Parser::AST::Function.new(
                :name => "template",
                :ftype => :rvalue,
                :arguments => AST::ASTArray.new(
                    :children => [stringobj("one"),
                        stringobj("two")]
                )
            )
        end
        ast = varobj("output", func)

        scope = mkscope
        assert_raise(Puppet::ParseError) do
            ast.evaluate(:scope => scope)
        end

        scope.setvar("one", "One")
        assert_raise(Puppet::ParseError) do
            ast.evaluate(:scope => scope)
        end
        scope.setvar("two", "Two")
        assert_nothing_raised do
            ast.evaluate(:scope => scope)
        end

        assert_equal("template One\ntemplate Two\n", scope.lookupvar("output"),
            "Templates were not handled correctly")
    end

    # Now make sure we can fully qualify files, and specify just one
    def test_singletemplates
        template = tempfile()

        File.open(template, "w") do |f|
            f.puts "template <%= yayness %>"
        end

        func = nil
        assert_nothing_raised do
            func = Puppet::Parser::AST::Function.new(
                :name => "template",
                :ftype => :rvalue,
                :arguments => AST::ASTArray.new(
                    :children => [stringobj(template)]
                )
            )
        end
        ast = varobj("output", func)

        scope = mkscope
        assert_raise(Puppet::ParseError) do
            ast.evaluate(:scope => scope)
        end

        scope.setvar("yayness", "this is yayness")

        assert_nothing_raised do
            ast.evaluate(:scope => scope)
        end

        assert_equal("template this is yayness\n", scope.lookupvar("output"),
            "Templates were not handled correctly")

    end

    def test_tempatefunction_cannot_see_scopes
        template = tempfile()

        File.open(template, "w") do |f|
            f.puts "<%= lookupvar('myvar') %>"
        end

        func = nil
        assert_nothing_raised do
            func = Puppet::Parser::AST::Function.new(
                :name => "template",
                :ftype => :rvalue,
                :arguments => AST::ASTArray.new(
                    :children => [stringobj(template)]
                )
            )
        end
        ast = varobj("output", func)

        scope = mkscope
        scope.setvar("myvar", "this is yayness")
        assert_raise(Puppet::ParseError) do
            ast.evaluate(:scope => scope)
        end
    end

    def test_template_reparses
        template = tempfile()

        File.open(template, "w") do |f|
            f.puts "original text"
        end

        manifest = tempfile()
        file = tempfile()
        File.open(manifest, "w") do |f|
            f.puts %{file { "#{file}": content => template("#{template}") }}
        end

        interpreter = Puppet::Parser::Interpreter.new(
            :Manifest => manifest,
            :UseNodes => false
        )

        parsedate = interpreter.parsedate()

        objects = nil
        assert_nothing_raised {
            objects = interpreter.run("myhost", {})
        }

        fileobj = objects[0]

        assert_equal("original text\n", fileobj["content"],
            "Template did not work")

        Puppet[:filetimeout] = 0
        # Have to sleep because one second is the fs's time granularity.
        sleep(1)

        # Now modify the template
        File.open(template, "w") do |f|
            f.puts "new text"
        end

        assert_nothing_raised {
            objects = interpreter.run("myhost", {})
        }
        newdate = interpreter.parsedate()

        assert(parsedate != newdate, "Parse date did not change")
    end

    def test_template_defined_vars
        template = tempfile()

        File.open(template, "w") do |f|
            f.puts "template <%= yayness %>"
        end

        func = nil
        assert_nothing_raised do
            func = Puppet::Parser::AST::Function.new(
                :name => "template",
                :ftype => :rvalue,
                :arguments => AST::ASTArray.new(
                    :children => [stringobj(template)]
                )
            )
        end
        ast = varobj("output", func)

        {
            "" => "",
            false => "false",
        }.each do |string, value|
            scope = mkscope
            assert_raise(Puppet::ParseError) do
                ast.evaluate(:scope => scope)
            end

            scope.setvar("yayness", string)
            assert_equal(string, scope.lookupvar("yayness", false))

            assert_nothing_raised("An empty string was not a valid variable value") do
                ast.evaluate(:scope => scope)
            end

            assert_equal("template #{value}\n", scope.lookupvar("output"),
                         "%s did not get evaluated correctly" % string.inspect)
        end
    end

    def test_autoloading_functions
        assert_equal(false, Puppet::Parser::Functions.function(:autofunc),
            "Got told autofunc already exists")

        dir = tempfile()
        $: << dir
        newpath = File.join(dir, "puppet", "parser", "functions")
        FileUtils.mkdir_p(newpath)

        File.open(File.join(newpath, "autofunc.rb"), "w") { |f|
            f.puts %{
                Puppet::Parser::Functions.newfunction(:autofunc, :type => :rvalue) do |vals|
                    Puppet.wanring vals.inspect
                end
            }
        }

        obj = nil
        assert_nothing_raised {
            obj = Puppet::Parser::Functions.function(:autofunc)
        }

        assert(obj, "Did not autoload function")
        assert(Puppet::Parser::Scope.method_defined?(:function_autofunc),
            "Did not set function correctly")
    end

    def test_realize
        @interp, @scope, @source = mkclassframing
    
        # Make a definition
        @interp.newdefine("mytype")
        
        [%w{file /tmp/virtual}, %w{mytype yay}].each do |type, title|
            # Make a virtual resource
            virtual = mkresource(:type => type, :title => title,
                :virtual => true, :params => {})
        
            @scope.setresource virtual

            ref = Puppet::Parser::Resource::Reference.new(
                :type => type, :title => title,
                :scope => @scope
            )
            # Now call the realize function
            assert_nothing_raised do
                @scope.function_realize(ref)
            end

            # Make sure it created a collection
            assert_equal(1, @scope.collections.length,
                "Did not set collection")

            assert_nothing_raised do
                @scope.collections.each do |coll| coll.evaluate end
            end
            @scope.collections.clear

            # Now make sure the virtual resource is no longer virtual
            assert(! virtual.virtual?, "Did not make virtual resource real")
        end

        # Make sure we puke on any resource that doesn't exist
        none = Puppet::Parser::Resource::Reference.new(
            :type => "file", :title => "/tmp/nosuchfile",
            :scope => @scope
        )

        # The function works
        assert_nothing_raised do
            @scope.function_realize(none.to_s)
        end

        # Make sure it created a collection
        assert_equal(1, @scope.collections.length,
            "Did not set collection")

        # And the collection has our resource in it
        assert_equal([none.to_s], @scope.collections[0].resources,
            "Did not set resources in collection")
    end
    
    def test_defined
        interp = mkinterp
        scope = mkscope(:interp => interp)
        
        interp.newclass("yayness")
        interp.newdefine("rahness")
        
        assert_nothing_raised do
            assert(scope.function_defined("yayness"), "yayness class was not considered defined")
            assert(scope.function_defined("rahness"), "rahness definition was not considered defined")
            assert(scope.function_defined("service"), "service type was not considered defined")
            assert(! scope.function_defined("fakness"), "fakeness was considered defined")
        end
        
        # Now make sure any match in a list will work
        assert(scope.function_defined(["booness", "yayness", "fakeness"]),
            "A single answer was not sufficient to return true")
        
        # and make sure multiple falses are still false
        assert(! scope.function_defined(%w{no otherno stillno}),
            "Multiple falses were somehow true")
        
        # Now make sure we can test resources
        scope.setresource mkresource(:type => "file", :title => "/tmp/rahness",
            :scope => scope, :source => scope.source,
            :params => {:owner => "root"})
        
        yep = Puppet::Parser::Resource::Reference.new(:type => "file", :title => "/tmp/rahness")
        nope = Puppet::Parser::Resource::Reference.new(:type => "file", :title => "/tmp/fooness")
        
        assert(scope.function_defined([yep]), "valid resource was not considered defined")
        assert(! scope.function_defined([nope]), "invalid resource was considered defined")
    end

    def test_search
        interp = mkinterp
        scope = mkscope(:interp => interp)
        
        fun = interp.newdefine("fun::test")
        foo = interp.newdefine("foo::bar")

        search = Puppet::Parser::Functions.function(:search)
        assert_nothing_raised do
            scope.function_search(["foo", "fun"])
        end

        ffun = ffoo = nil
        assert_nothing_raised do
            ffun = scope.finddefine("test")
            ffoo = scope.finddefine('bar')
        end

        assert(ffun, "Could not find definition in 'fun' namespace")
        assert(ffoo, "Could not find definition in 'foo' namespace")
    end
end

# $Id$
