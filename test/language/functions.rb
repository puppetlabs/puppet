#!/usr/bin/ruby

require 'puppet'
require 'puppet/parser/interpreter'
require 'puppet/parser/parser'
require 'puppet/client'
require 'puppettest'

class TestLangFunctions < Test::Unit::TestCase
    include PuppetTest::ParserTesting
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
            Puppet::Parser::Functions.newfunction(:fakefunction, :rvalue) do |input|
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
                Puppet::Parser::Functions.newfunction(:autofunc, :rvalue) do |vals|
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
end

# $Id$
