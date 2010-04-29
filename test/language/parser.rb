#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../lib/puppettest'

require 'mocha'
require 'puppet'
require 'puppet/parser/parser'
require 'puppettest'
require 'puppettest/support/utils'

class TestParser < Test::Unit::TestCase
    include PuppetTest
    include PuppetTest::ParserTesting
    include PuppetTest::Support::Utils
    def setup
        super
        Puppet[:parseonly] = true
        #@lexer = Puppet::Parser::Lexer.new()
    end

    def teardown
        super
        Puppet::Node::Environment.clear
    end

    def test_each_file
        textfiles { |file|
            Puppet::Node::Environment.clear
            parser = mkparser
            Puppet.debug("parsing %s" % file) if __FILE__ == $0
            assert_nothing_raised() {
                parser.file = file
                parser.parse
            }
        }
    end

    def test_failers
        failers { |file|
            parser = mkparser
            Puppet.debug("parsing failer %s" % file) if __FILE__ == $0
            assert_raise(Puppet::ParseError, "Did not fail while parsing %s" % file) {
                parser.file = file
                ast = parser.parse
                config = mkcompiler(parser)
                config.compile
                #ast.hostclass("").evaluate config.topscope
            }
        }
    end

    def test_arrayrvalues
        parser = mkparser
        ret = nil
        file = tempfile()
        assert_nothing_raised {
            parser.string = "file { \"#{file}\": mode => [755, 640] }"
        }

        assert_nothing_raised {
            ret = parser.parse
        }
    end

    def test_arrayrvalueswithtrailingcomma
        parser = mkparser
        ret = nil
        file = tempfile()
        assert_nothing_raised {
            parser.string = "file { \"#{file}\": mode => [755, 640,] }"
        }

        assert_nothing_raised {
            ret = parser.parse
        }
    end

    def mkmanifest(file)
        name = File.join(tmpdir, "file%s" % rand(100))
        @@tmpfiles << name

        File.open(file, "w") { |f|
            f.puts "file { \"%s\": ensure => file, mode => 755 }\n" %
               name
        }
    end

    def test_importglobbing
        basedir = File.join(tmpdir(), "importesting")
        @@tmpfiles << basedir
        Dir.mkdir(basedir)

        subdir = "subdir"
        Dir.mkdir(File.join(basedir, subdir))
        manifest = File.join(basedir, "manifest")
        File.open(manifest, "w") { |f|
            f.puts "import \"%s/*\"" % subdir
        }

        4.times { |i|
            path = File.join(basedir, subdir, "subfile%s" % i)
            mkmanifest(path)
        }

        assert_nothing_raised("Could not parse multiple files") {
            parser = mkparser
            parser.file = manifest
            parser.parse
        }
    end

    def test_nonexistent_import
        basedir = File.join(tmpdir(), "importesting")
        @@tmpfiles << basedir
        Dir.mkdir(basedir)
        manifest = File.join(basedir, "manifest")
        File.open(manifest, "w") do |f|
            f.puts "import \" no such file \""
        end
        assert_raise(Puppet::ParseError) {
            parser = mkparser
            parser.file = manifest
            parser.parse
        }
    end

    def test_trailingcomma
        path = tempfile()
        str = %{file { "#{path}": ensure => file, }
        }

        parser = mkparser
        parser.string = str

        assert_nothing_raised("Could not parse trailing comma") {
            parser.parse
        }
    end

    def test_importedclasses
        imported = tempfile()
        importer = tempfile()

        made = tempfile()

        File.open(imported, "w") do |f|
            f.puts %{class foo { file { "#{made}": ensure => file }}}
        end

        File.open(importer, "w") do |f|
            f.puts %{import "#{imported}"\ninclude foo}
        end

        parser = mkparser
        parser.file = importer

        # Make sure it parses fine
        assert_nothing_raised {
            parser.parse
        }

        # Now make sure it actually does the work
        assert_creates(importer, made)
    end

    # Make sure fully qualified and unqualified files can be imported
    def test_fqfilesandlocalfiles
        dir = tempfile()
        Dir.mkdir(dir)
        importer = File.join(dir, "site.pp")
        fullfile = File.join(dir, "full.pp")
        localfile = File.join(dir, "local.pp")

        files = []

        File.open(importer, "w") do |f|
            f.puts %{import "#{fullfile}"\ninclude full\nimport "local.pp"\ninclude local}
        end

        fullmaker = tempfile()
        files << fullmaker

        File.open(fullfile, "w") do |f|
            f.puts %{class full { file { "#{fullmaker}": ensure => file }}}
        end

        localmaker = tempfile()
        files << localmaker

        File.open(localfile, "w") do |f|
            f.puts %{class local { file { "#{localmaker}": ensure => file }}}
        end

        parser = mkparser
        parser.file = importer

        # Make sure it parses
        assert_nothing_raised {
            parser.parse
        }

        # Now make sure it actually does the work
        assert_creates(importer, *files)
    end

    # Make sure the parser adds '.pp' when necessary
    def test_addingpp
        dir = tempfile()
        Dir.mkdir(dir)
        importer = File.join(dir, "site.pp")
        localfile = File.join(dir, "local.pp")

        files = []

        File.open(importer, "w") do |f|
            f.puts %{import "local"\ninclude local}
        end

        file = tempfile()
        files << file

        File.open(localfile, "w") do |f|
            f.puts %{class local { file { "#{file}": ensure => file }}}
        end

        parser = mkparser
        parser.file = importer

        assert_nothing_raised {
            parser.parse
        }
    end

    # Make sure that file importing changes file relative names.
    def test_changingrelativenames
        dir = tempfile()
        Dir.mkdir(dir)
        Dir.mkdir(File.join(dir, "subdir"))
        top = File.join(dir, "site.pp")
        subone = File.join(dir, "subdir/subone")
        subtwo = File.join(dir, "subdir/subtwo")

        files = []
        file = tempfile()
        files << file

        File.open(subone + ".pp", "w") do |f|
            f.puts %{class one { file { "#{file}": ensure => file }}}
        end

        otherfile = tempfile()
        files << otherfile
        File.open(subtwo + ".pp", "w") do |f|
            f.puts %{import "subone"\n class two inherits one {
                file { "#{otherfile}": ensure => file }
            }}
        end

        File.open(top, "w") do |f|
            f.puts %{import "subdir/subtwo"}
        end

        parser = mkparser
        parser.file = top

        assert_nothing_raised {
            parser.parse
        }
    end

    # Defaults are purely syntactical, so it doesn't make sense to be able to
    # collect them.
    def test_uncollectabledefaults
        string = "@Port { protocols => tcp }"

        assert_raise(Puppet::ParseError) {
            mkparser.parse(string)
        }
    end

    # Verify that we can parse collections
    def test_collecting
        text = "Port <| |>"
        parser = mkparser
        parser.string = text

        ret = nil
        assert_nothing_raised {
            ret = parser.parse
        }

        ret.hostclass("").code.each do |obj|
            assert_instance_of(AST::Collection, obj)
        end
    end

    def test_emptyfile
        file = tempfile()
        File.open(file, "w") do |f|
            f.puts %{}
        end
        parser = mkparser
        parser.file = file
        assert_nothing_raised {
            parser.parse
        }
    end

    def test_multiple_nodes_named
        file = tempfile()
        other = tempfile()

        File.open(file, "w") do |f|
            f.puts %{
node nodeA, nodeB {
    file { "#{other}": ensure => file }

}
}
        end

        parser = mkparser
        parser.file = file
        ast = nil
        assert_nothing_raised {
            ast = parser.parse
        }
    end

    def test_emptyarrays
        str = %{$var = []\n}

        parser = mkparser
        parser.string = str

        # Make sure it parses fine
        assert_nothing_raised {
            parser.parse
        }
    end

    # Make sure function names aren't reserved words.
    def test_functionnamecollision
        str = %{tag yayness
tag(rahness)

file { "/tmp/yayness":
    tag => "rahness",
    ensure => exists
}
}
        parser = mkparser
        parser.string = str

        # Make sure it parses fine
        assert_nothing_raised {
            parser.parse
        }
    end

    def test_metaparams_in_definition_prototypes
        parser = mkparser


        assert_raise(Puppet::ParseError) {
            parser.parse %{define mydef($schedule) {}}
        }

        assert_nothing_raised {
            parser.parse %{define adef($schedule = false) {}}
            parser.parse %{define mydef($schedule = daily) {}}
        }
    end

    def test_parsingif
        parser = mkparser
        exec = proc do |val|
            %{exec { "/bin/echo #{val}": logoutput => true }}
        end
        str1 = %{if true { #{exec.call("true")} }}
        ret = nil
        assert_nothing_raised {
            ret = parser.parse(str1).hostclass("").code[0]
        }
        assert_instance_of(Puppet::Parser::AST::IfStatement, ret)
        parser = mkparser
        str2 = %{if true { #{exec.call("true")} } else { #{exec.call("false")} }}
        ret = parser.parse(str2).hostclass("").code[0]
        assert_instance_of(Puppet::Parser::AST::IfStatement, ret)
        assert_instance_of(Puppet::Parser::AST::Else, ret.else)
    end

    def test_hostclass
        parser = mkparser

        assert_nothing_raised {
            parser.parse %{class myclass { class other {} }}
        }
        assert(parser.hostclass("myclass"), "Could not find myclass")
        assert(parser.hostclass("myclass::other"), "Could not find myclass::other")

        assert_nothing_raised {
            parser.parse "class base {}
            class container {
                class deep::sub inherits base {}
            }"
        }
        sub = parser.hostclass("container::deep::sub")
        assert(sub, "Could not find sub")

        # Now try it with a parent class being a fq class
        assert_nothing_raised {
            parser.parse "class container::one inherits container::deep::sub {}"
        }
        sub = parser.hostclass("container::one")
        assert(sub, "Could not find one")
        assert_equal("container::deep::sub", sub.parent)

        # Finally, try including a qualified class
        assert_nothing_raised("Could not include fully qualified class") {
            parser.parse "include container::deep::sub"
        }
    end

    def test_topnamespace
        parser = mkparser

        # Make sure we put the top-level code into a class called "" in
        # the "" namespace
        assert_nothing_raised do
            out = parser.parse ""

            assert_instance_of(Puppet::Resource::TypeCollection, out)
            assert_nil(parser.hostclass(""), "Got a 'main' class when we had no code")
        end

        # Now try something a touch more complicated
        parser.initvars
        assert_nothing_raised do
            out = parser.parse "Exec { path => '/usr/bin:/usr/sbin' }"
            assert_instance_of(Puppet::Resource::TypeCollection, out)
            assert_equal("", parser.hostclass("").name)
            assert_equal("", parser.hostclass("").namespace)
        end
    end

    # Make sure virtual and exported resources work appropriately.
    def test_virtualresources
        tests = [:virtual]
        if Puppet.features.rails?
            catalog_cache_class = Puppet::Resource::Catalog.indirection.cache_class
            facts_cache_class = Puppet::Node::Facts.indirection.cache_class
            node_cache_class = Puppet::Node.indirection.cache_class
            Puppet[:storeconfigs] = true
            tests << :exported
        end

        tests.each do |form|
            parser = mkparser

            if form == :virtual
                at = "@"
            else
                at = "@@"
            end

            check = proc do |res, msg|
                if res.is_a?(Puppet::Parser::Resource)
                    txt = res.ref
                else
                    txt = res.class
                end
                # Real resources get marked virtual when exported
                if form == :virtual or res.is_a?(Puppet::Parser::Resource)
                    assert(res.virtual, "#{msg} #{at}#{txt} is not virtual")
                end
                if form == :virtual
                    assert(! res.exported, "#{msg} #{at}#{txt} is exported")
                else
                    assert(res.exported, "#{msg} #{at}#{txt} is not exported")
                end
            end

            ret = nil
            assert_nothing_raised do
                ret = parser.parse("#{at}file { '/tmp/testing': owner => root }")
            end

            assert_instance_of(AST::ASTArray, ret.hostclass("").code)
            resdef = ret.hostclass("").code[0]
            assert_instance_of(AST::Resource, resdef)
            assert_equal("/tmp/testing", resdef.title.value)
            # We always get an astarray back, so...
            check.call(resdef, "simple resource")

            # Now let's try it with multiple resources in the same spec
            assert_nothing_raised do
                ret = parser.parse("#{at}file { ['/tmp/1', '/tmp/2']: owner => root }")
            end

            ret.hostclass("").code.each do |res|
                assert_instance_of(AST::Resource, res)
                check.call(res, "multiresource")
            end
        end

    ensure
        if Puppet.features.rails?
            Puppet[:storeconfigs] = false
            Puppet::Resource::Catalog.cache_class =  catalog_cache_class
            Puppet::Node::Facts.cache_class = facts_cache_class
            Puppet::Node.cache_class = node_cache_class
        end
    end

    def test_collections
        tests = [:virtual]
        if Puppet.features.rails?
            catalog_cache_class = Puppet::Resource::Catalog.indirection.cache_class
            facts_cache_class = Puppet::Node::Facts.indirection.cache_class
            node_cache_class = Puppet::Node.indirection.cache_class
            Puppet[:storeconfigs] = true
            tests << :exported
        end

        tests.each do |form|
            Puppet::Node::Environment.clear
            parser = mkparser

            if form == :virtual
                arrow = "<||>"
            else
                arrow = "<<||>>"
            end

            ret = nil
            assert_nothing_raised do
                ret = parser.parse("File #{arrow}")
            end

            coll = ret.hostclass("").code[0]
            assert_instance_of(AST::Collection, coll)
            assert_equal(form, coll.form)
        end

    ensure
        if Puppet.features.rails?
            Puppet[:storeconfigs] = false
            Puppet::Resource::Catalog.cache_class =  catalog_cache_class
            Puppet::Node::Facts.cache_class = facts_cache_class
            Puppet::Node.cache_class = node_cache_class
        end
    end

    def test_collectionexpressions
        %w{== !=}.each do |oper|
            Puppet::Node::Environment.clear
            str = "File <| title #{oper} '/tmp/testing' |>"

            parser = mkparser

            res = nil
            assert_nothing_raised do
                res = parser.parse(str).hostclass("").code[0]
            end

            assert_instance_of(AST::Collection, res)

            query = res.query
            assert_instance_of(AST::CollExpr, query)

            assert_equal(:virtual, query.form)
            assert_equal("title", query.test1.value)
            assert_equal("/tmp/testing", query.test2.value)
            assert_equal(oper, query.oper)
        end
    end

    def test_collectionstatements
        %w{and or}.each do |joiner|
            str = "File <| title == '/tmp/testing' #{joiner} owner == root |>"

            parser = mkparser

            res = nil
            assert_nothing_raised do
                res = parser.parse(str).hostclass("").code[0]
            end

            assert_instance_of(AST::Collection, res)

            query = res.query
            assert_instance_of(AST::CollExpr, query)

            assert_equal(joiner, query.oper)
            assert_instance_of(AST::CollExpr, query.test1)
            assert_instance_of(AST::CollExpr, query.test2)
        end
    end

    def test_collectionstatements_with_parens
        [
            "(title == '/tmp/testing' and owner == root) or owner == wheel",
            "(title == '/tmp/testing')"
        ].each do |test|
            str = "File <| #{test} |>"
            parser = mkparser

            res = nil
            assert_nothing_raised("Could not parse '#{test}'") do
                res = parser.parse(str).hostclass("").code[0]
            end

            assert_instance_of(AST::Collection, res)

            query = res.query
            assert_instance_of(AST::CollExpr, query)

            #assert_equal(joiner, query.oper)
            #assert_instance_of(AST::CollExpr, query.test1)
            #assert_instance_of(AST::CollExpr, query.test2)
        end
    end

    def test_fully_qualified_definitions
        parser = mkparser

        assert_nothing_raised("Could not parse fully-qualified definition") {
            parser.parse %{define one::two { }}
        }
        assert(parser.definition("one::two"), "Could not find one::two with no namespace")

        # Now try using the definition
        assert_nothing_raised("Could not parse fully-qualified definition usage") {
            parser.parse %{one::two { yayness: }}
        }
    end

    # #524
    def test_functions_with_no_arguments
        parser = mkparser
        assert_nothing_raised("Could not parse statement function with no args") {
            parser.parse %{tag()}
        }
        assert_nothing_raised("Could not parse rvalue function with no args") {
            parser.parse %{$testing = template()}
        }
    end

    # #774
    def test_fully_qualified_collection_statement
        parser = mkparser
        assert_nothing_raised("Could not parse fully qualified collection statement") {
            parser.parse %{Foo::Bar <||>}
        }
    end

    def test_multiple_imports_on_one_line
        one = tempfile
        two = tempfile
        base = tempfile
        File.open(one, "w") { |f| f.puts "$var = value" }
        File.open(two, "w") { |f| f.puts "$var = value" }
        File.open(base, "w") { |f| f.puts "import '#{one}', '#{two}'" }

        parser = mkparser
        parser.file = base

        # Importing is logged at debug time.
        Puppet::Util::Log.level = :debug
        assert_nothing_raised("Parser could not import multiple files at once") do
            parser.parse
        end

        [one, two].each do |file|
            assert(@logs.detect { |l| l.message =~ /importing '#{file}'/},
                "did not import %s" % file)
        end
    end

    def test_cannot_assign_qualified_variables
        parser = mkparser
        assert_raise(Puppet::ParseError, "successfully assigned a qualified variable") do
            parser.parse("$one::two = yay")
        end
    end

    # #629 - undef keyword
    def test_undef
        parser = mkparser
        result = nil
        assert_nothing_raised("Could not parse assignment to undef") {
            result = parser.parse %{$variable = undef}
        }

        main = result.hostclass("").code
        children = main.children
        assert_instance_of(AST::VarDef, main.children[0])
        assert_instance_of(AST::Undef, main.children[0].value)
    end

    # Prompted by #729 -- parsing should not modify the interpreter.
    def test_parse
        parser = mkparser

        str = "file { '/tmp/yay': ensure => file }\nclass yay {}\nnode foo {}\ndefine bar {}\n"
        result = nil
        assert_nothing_raised("Could not parse") do
            result = parser.parse(str)
        end
        assert_instance_of(Puppet::Resource::TypeCollection, result, "Did not get a ASTSet back from parsing")

        assert_instance_of(Puppet::Resource::Type, result.hostclass("yay"), "Did not create 'yay' class")
        assert_instance_of(Puppet::Resource::Type, result.hostclass(""), "Did not create main class")
        assert_instance_of(Puppet::Resource::Type, result.definition("bar"), "Did not create 'bar' definition")
        assert_instance_of(Puppet::Resource::Type, result.node("foo"), "Did not create 'foo' node")
    end

    def test_namesplit
        parser = mkparser

        assert_nothing_raised do
            {"base::sub" => %w{base sub},
                "main" => ["", "main"],
                "one::two::three::four" => ["one::two::three", "four"],
            }.each do |name, ary|
                result = parser.namesplit(name)
                assert_equal(ary, result, "%s split to %s" % [name, result])
            end
        end
    end

    # Make sure class, node, and define methods are case-insensitive
    def test_structure_case_insensitivity
        parser = mkparser

        result = nil
        assert_nothing_raised do
            result = parser.newclass "Yayness"
        end
        assert_equal(result, parser.find_hostclass("", "yayNess"))

        assert_nothing_raised do
            result = parser.newdefine "FunTest"
        end
        assert_equal(result, parser.find_definition("", "fUntEst"),
            "%s was not matched" % "fUntEst")
    end
end
