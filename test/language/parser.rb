#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppet/parser/parser'
require 'puppettest'

class TestParser < Test::Unit::TestCase
    include PuppetTest::ParserTesting
    def setup
        super
        Puppet[:parseonly] = true
        #@lexer = Puppet::Parser::Lexer.new()
    end

    def test_each_file
        textfiles { |file|
            parser = mkparser
            Puppet.debug("parsing %s" % file) if __FILE__ == $0
            assert_nothing_raised() {
                parser.file = file
                parser.parse
            }

            Puppet::Type.eachtype { |type|
                type.each { |obj|
                    assert(obj.file, "File is not set on %s" % obj.ref)
                    assert(obj.name, "Name is not set on %s" % obj.ref)
                    assert(obj.line, "Line is not set on %s" % obj.ref)
                }
            }
            Puppet::Type.allclear
        }
    end

    def test_failers
        failers { |file|
            parser = mkparser
            Puppet.debug("parsing failer %s" % file) if __FILE__ == $0
            assert_raise(Puppet::ParseError) {
                parser.file = file
                ast = parser.parse
                scope = mkscope :interp => parser.interp
                ast.evaluate :scope => scope
            }
            Puppet::Type.allclear
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

        assert_instance_of(AST::ASTArray, ret)

        ret.each do |obj|
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
            ret = parser.parse(str1)[0]
        }
        assert_instance_of(Puppet::Parser::AST::IfStatement, ret)
        str2 = %{if true { #{exec.call("true")} } else { #{exec.call("false")} }}
        assert_nothing_raised {
            ret = parser.parse(str2)[0]
        }
        assert_instance_of(Puppet::Parser::AST::IfStatement, ret)
        assert_instance_of(Puppet::Parser::AST::Else, ret.else)
    end

    def test_hostclass
        parser = mkparser
        interp = parser.interp

        assert_nothing_raised {
            parser.parse %{class myclass { class other {} }}
        }
        assert(interp.findclass("", "myclass"), "Could not find myclass")
        assert(interp.findclass("", "myclass::other"), "Could not find myclass::other")

        assert_nothing_raised {
            parser.parse "class base {}
            class container {
                class deep::sub inherits base {}
            }"
        }
        sub = interp.findclass("", "container::deep::sub")
        assert(sub, "Could not find sub")
        assert_equal("base", sub.parentobj.classname)
        
        # Now try it with a parent class being a fq class
        assert_nothing_raised {
            parser.parse "class container::one inherits container::deep::sub {}"
        }
        sub = interp.findclass("", "container::one")
        assert(sub, "Could not find one")
        assert_equal("container::deep::sub", sub.parentobj.classname)
        
        # Finally, try including a qualified class
        assert_nothing_raised("Could not include fully qualified class") {
            parser.parse "include container::deep::sub"
        }
    end

    def test_topnamespace
        parser = mkparser
        parser.interp.clear

        # Make sure we put the top-level code into a class called "" in
        # the "" namespace
        assert_nothing_raised do
            out = parser.parse ""

            assert_nil(out)
            assert_nil(parser.interp.findclass("", ""))
        end

        # Now try something a touch more complicated
        parser.interp.clear
        assert_nothing_raised do
            out = parser.parse "Exec { path => '/usr/bin:/usr/sbin' }"
            assert_instance_of(AST::ASTArray, out)
            assert_equal("", parser.interp.findclass("", "").classname)
            assert_equal("", parser.interp.findclass("", "").namespace)
            assert_equal(out.object_id, parser.interp.findclass("", "").code.object_id)
        end
    end

    # Make sure virtual and exported resources work appropriately.
    def test_virtualresources
        tests = [:virtual]
        if Puppet.features.rails?
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

            assert_equal("/tmp/testing", ret[0].title.value)
            # We always get an astarray back, so...
            assert_instance_of(AST::ResourceDef, ret[0])
            check.call(ret[0], "simple resource")

            # Now let's try it with multiple resources in the same spec
            assert_nothing_raised do
                ret = parser.parse("#{at}file { ['/tmp/1', '/tmp/2']: owner => root }")
            end

            assert_instance_of(AST::ASTArray, ret)
            ret.each do |res|
                assert_instance_of(AST::ResourceDef, res)
                check.call(res, "multiresource")
            end

            # Now evaluate these
            scope = mkscope

            klass = scope.interp.newclass ""
            scope.source = klass

            assert_nothing_raised do
                ret.evaluate :scope => scope
            end

            # Make sure we can find both of them
            %w{/tmp/1 /tmp/2}.each do |title|
                res = scope.findresource("File[#{title}]")
                assert(res, "Could not find %s" % title)
                check.call(res, "found multiresource")
            end
        end
    end

    def test_collections
        tests = [:virtual]
        if Puppet.features.rails?
            Puppet[:storeconfigs] = true
            tests << :exported
        end

        tests.each do |form|
            parser = mkparser

            if form == :virtual
                arrow = "<||>"
            else
                arrow = "<<||>>"
            end

            check = proc do |coll|
                assert_instance_of(AST::Collection, coll)
                assert_equal(form, coll.form)
            end

            ret = nil
            assert_nothing_raised do
                ret = parser.parse("File #{arrow}")
            end
            check.call(ret[0])
        end
    end

    def test_collectionexpressions
        %w{== !=}.each do |oper|
            str = "File <| title #{oper} '/tmp/testing' |>"

            parser = mkparser

            res = nil
            assert_nothing_raised do
                res = parser.parse(str)[0]
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
                res = parser.parse(str)[0]
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
                res = parser.parse(str)[0]
            end

            assert_instance_of(AST::Collection, res)

            query = res.query
            assert_instance_of(AST::CollExpr, query)

            #assert_equal(joiner, query.oper)
            #assert_instance_of(AST::CollExpr, query.test1)
            #assert_instance_of(AST::CollExpr, query.test2)
        end
    end

    # We've had problems with files other than site.pp importing into main.
    def test_importing_into_main
        top = tempfile()
        other = tempfile()
        File.open(top, "w") do |f|
            f.puts "import '#{other}'"
        end

        file = tempfile()
        File.open(other, "w") do |f|
            f.puts "file { '#{file}': ensure => present }"
        end

        interp = mkinterp :Manifest => top, :UseNodes => false

        code = nil
        assert_nothing_raised do
            code = interp.run("hostname.domain.com", {}).flatten
        end
        assert(code.length == 1, "Did not get the file")
        assert_instance_of(Puppet::TransObject, code[0])
    end
    
    def test_fully_qualified_definitions
        parser = mkparser
        interp = parser.interp

        assert_nothing_raised("Could not parse fully-qualified definition") {
            parser.parse %{define one::two { }}
        }
        assert(interp.finddefine("", "one::two"), "Could not find one::two with no namespace")
        assert(interp.finddefine("one", "two"), "Could not find two in namespace one")
        
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

    def test_module_import
        basedir = File.join(tmpdir(), "module-import")
        @@tmpfiles << basedir
        Dir.mkdir(basedir)
        modfiles = [ "init.pp", "mani1.pp", "mani2.pp",
                     "sub/smani1.pp", "sub/smani2.pp" ]

        modpath = File.join(basedir, "modules")
        Puppet[:modulepath] = modpath

        modname = "amod"
        manipath = File::join(modpath, modname, Puppet::Module::MANIFESTS)
        FileUtils::mkdir_p(File::join(manipath, "sub"))
        targets = []
        modfiles.each do |fname|
            target = File::join(basedir, File::basename(fname, '.pp'))
            targets << target
            txt = %[ file { '#{target}': content => "#{fname}" } ]
            if fname == "init.pp"
                txt = %[import 'mani1' \nimport '#{modname}/mani2'\nimport '#{modname}/sub/*.pp' ] + txt
            end
            File::open(File::join(manipath, fname), "w") do |f|
                f.puts txt
            end
        end

        manifest_texts = [ "import '#{modname}'",
                           "import '#{modname}/init'",
                           "import '#{modname}/init.pp'" ]

        manifest = File.join(modpath, "manifest.pp")
        manifest_texts.each do |txt|
            File.open(manifest, "w") { |f| f.puts txt }

            assert_nothing_raised {
                parser = mkparser
                parser.file = manifest
                parser.parse
            }
            assert_creates(manifest, *targets)
        end
    end

    # #544
    def test_ignoreimports
        parser = mkparser

        assert(! Puppet[:ignoreimport], ":ignoreimport defaulted to true")
        assert_raise(Puppet::ParseError, "Did not fail on missing import") do
            parser.parse("import 'nosuchfile'")
        end
        assert_nothing_raised("could not set :ignoreimport") do
            Puppet[:ignoreimport] = true
        end
        assert_nothing_raised("Parser did not follow :ignoreimports") do
            parser.parse("import 'nosuchfile'")
        end
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

    # #588
    def test_globbing_with_directories
        dir = tempfile
        Dir.mkdir(dir)
        subdir = File.join(dir, "subdir")
        Dir.mkdir(subdir)
        file = File.join(dir, "file.pp")
        maker = tempfile
        File.open(file, "w") { |f| f.puts "file { '#{maker}': ensure => file }" }

        parser = mkparser
        assert_nothing_raised("Globbing failed when it matched a directory") do
            parser.import("%s/*" % dir)
        end
    end
end

# $Id$
