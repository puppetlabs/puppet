if __FILE__ == $0
    $:.unshift '../../lib'
    $:.unshift '..'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppet/parser/parser'
require 'test/unit'
require 'puppettest'

class TestParser < TestPuppet
    def setup
        super
        Puppet[:parseonly] = true
        #@lexer = Puppet::Parser::Lexer.new()
        @parser = Puppet::Parser::Parser.new()
    end

    def test_each_file
        textfiles { |file|
            Puppet.debug("parsing %s" % file) if __FILE__ == $0
            assert_nothing_raised() {
                @parser.file = file
                @parser.parse
            }

            Puppet::Type.eachtype { |type|
                type.each { |obj|
                    assert(obj.file)
                    assert(obj.name)
                    assert(obj.line)
                }
            }
            Puppet::Type.allclear
        }
    end

    def test_failers
        failers { |file|
            Puppet.debug("parsing failer %s" % file) if __FILE__ == $0
            assert_raise(Puppet::ParseError) {
                @parser.file = file
                @parser.parse
            }
            Puppet::Type.allclear
        }
    end

    def test_arrayrvalues
        parser = Puppet::Parser::Parser.new()
        ret = nil
        assert_nothing_raised {
            parser.string = 'file { "/tmp/testing": mode => [755, 640] }'
        }

        assert_nothing_raised {
            ret = parser.parse
        }
    end

    def mkmanifest(file)
        name = File.join(tmpdir, "file%s" % rand(100))
        @@tmpfiles << name

        File.open(file, "w") { |f|
            f.puts "file { \"%s\": create => true, mode => 755 }\n" %
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
            parser = Puppet::Parser::Parser.new()
            parser.file = manifest
            parser.parse
        }
    end

    def test_zdefaults
        basedir = File.join(tmpdir(), "defaulttesting")
        @@tmpfiles << basedir
        Dir.mkdir(basedir)

        defs1 = {
            "testing" => "value"
        }

        defs2 = {
            "one" => "two",
            "three" => "four",
            "five" => false,
            "seven" => "eight",
            "nine" => true,
            "eleven" => "twelve"
        }

        mkdef = proc { |hash|
            hash.collect { |arg, value|
                "%s = %s" % [arg, value]
            }.join(", ")
        }
        manifest = File.join(basedir, "manifest")
        File.open(manifest, "w") { |f|
            f.puts "
    define method(#{mkdef.call(defs1)}, other) {
        $variable = $testing
    }

    define othermethod(#{mkdef.call(defs2)}, goodness) {
        $more = less
    }

    method {
        other => yayness
    }

    othermethod {
        goodness => rahness
    }
"
        }

        ast = nil
        assert_nothing_raised("Could not parse multiple files") {
            parser = Puppet::Parser::Parser.new()
            parser.file = manifest
            ast = parser.parse
        }

        assert(ast, "Did not receive AST while parsing defaults")

        scope = nil
        assert_nothing_raised("Could not evaluate defaults parse tree") {
            scope = Puppet::Parser::Scope.new()
            objects = scope.evaluate(ast)
        }

        method = nil
        othermethod = nil
        assert_nothing_raised {
            method = scope.find { |child|
                child.is_a?(Puppet::Parser::Scope) and child.type == "method"
            }
            defs1.each { |var, value|
                curval = method.lookupvar(var)
                assert_equal(value, curval, "Did not get default")
            }
        }

        assert_nothing_raised {
            method = scope.find { |child|
                child.is_a?(Puppet::Parser::Scope) and child.type == "othermethod"
            }
            defs2.each { |var, value|
                curval = method.lookupvar(var)
                assert_equal(value, curval, "Did not get default")
            }
        }
    end
end

# $Id$
