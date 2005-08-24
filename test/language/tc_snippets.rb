#!/usr/bin/ruby -w

if __FILE__ == $0
    $:.unshift '../../lib'
    $:.unshift '..'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppet/parser/interpreter'
require 'puppet/parser/parser'
require 'puppet/client'
require 'puppet/server'
require 'test/unit'
require 'puppettest'

# so, what kind of things do we want to test?

# we don't need to test function, since we're confident in the
# library tests.  We do, however, need to test how things are actually
# working in the language.

# so really, we want to do things like test that our ast is correct
# and test whether we've got things in the right scopes

class TestSnippets < Test::Unit::TestCase
    $snippetbase = File.join($puppetbase, "examples", "code", "snippets")
    
    def file2ast(file)
        parser = Puppet::Parser::Parser.new()
        parser.file = file
        ast = parser.parse

        return ast
    end

    def snippet2ast(text)
        parser = Puppet::Parser::Parser.new()
        parser.string = text
        ast = parser.parse

        return ast
    end

    def client
        args = {
            :Listen => false
        }
        Puppet::Client.new(args)
    end

    def ast2scope(ast)
        interp = Puppet::Parser::Interpreter.new(
            :ast => ast,
            :client => client()
        )
        scope = Puppet::Parser::Scope.new()
        ast.evaluate(scope)

        return scope
    end

    def scope2objs(scope)
        objs = scope.to_trans
    end

    def snippet2scope(snippet)
        ast = snippet2ast(snippet)
        scope = ast2scope(ast)
    end

    def snippet2objs(snippet)
        ast = snippet2ast(snippet)
        scope = ast2scope(ast)
        objs = scope2objs(scope)
    end

    def states(type)
        states = []
        
        type.buildstatehash
        type.validstates.each { |name,state|
            states.push name
        }

        #if states.length == 0
        #    raise "%s has no states" % type
        #end

        states
    end

    def metaparams(type)
        mparams = []
        Puppet::Type.eachmetaparam { |param|
            mparams.push param
        }

        mparams
    end

    def params(type)
        params = []
        type.parameters.each { |name,state|
            params.push name
        }

        params
    end

    def randthing(thing,type)
        list = self.send(thing,type)
        list[rand(list.length)]
    end

    def randeach(type)
        [:states, :metaparams, :params].collect { |thing|
            randthing(thing,type)
        }
    end

    @@snippets = {
        true => [
            %{File { mode => 755 }}
        ],
    }

    def disabled_test_defaults
        Puppet::Type.eachtype { |type|
            next if type.name == :puppet or type.name == :component
            
            rands = randeach(type)

            name = type.name.to_s.capitalize

            [0..1, 0..2].each { |range|
                params = rands[range]
                paramstr = params.collect { |param|
                    "%s => fake" % param
                }.join(", ")

                str = "%s { %s }" % [name, paramstr]

                scope = nil
                assert_nothing_raised {
                    scope = snippet2scope(str)
                }

                defaults = nil
                assert_nothing_raised {
                    defaults = scope.lookupdefaults(name)
                }

                p defaults

                params.each { |param|
                    puts "%s => '%s'" % [name,param]
                    assert(defaults.include?(param))
                }
            }
        }
    end

    def setup
        Puppet[:loglevel] = :debug if __FILE__ == $0
        @@tmpfiles = []
    end

    def teardown
        @@tmpfiles.flatten.each { |file|
            if FileTest.exists?(file)
                File.unlink(file)
            end
        }
        Puppet::Type.allclear
    end

    # this is here in case no tests get defined; otherwise we get a warning
    def test_nothing
    end

    def snippet_filecreate(trans)
        %w{a b c d}.each { |letter|
            file = "/tmp/create%stest" % letter
            Puppet.info "testing %s" % file
            assert(Puppet::Type::PFile[file])
            assert(FileTest.exists?(file))
            @@tmpfiles << file
        }
        %w{a b}.each { |letter|
            file = "/tmp/create%stest" % letter
            assert(File.stat(file).mode & 007777 == 0755)
        }

        assert_nothing_raised {
            trans.rollback
        }
        %w{a b c d}.each { |letter|
            file = "/tmp/create%stest" % letter
            assert(! FileTest.exists?(file))
        }
    end

    def snippet_simpledefaults(trans)
        file = "/tmp/defaulttest"
        @@tmpfiles << file
        assert(FileTest.exists?(file))
        assert(File.stat(file).mode & 007777 == 0755)

        assert_nothing_raised {
            trans.rollback
        }
        assert(! FileTest.exists?(file))
    end

    def snippet_simpleselector(trans)
        files = %w{a b c d}.collect { |letter|
            "/tmp/snippetselect%stest" % letter
        }
        @@tmpfiles << files

        files.each { |file|
            assert(FileTest.exists?(file))
            assert(File.stat(file).mode & 007777 == 0755)
            @@tmpfiles << file
        }

        assert_nothing_raised {
            trans.rollback
        }
        files.each { |file|
            assert(! FileTest.exists?(file))
        }
    end

    def snippet_classpathtest(trans)
        file = "/tmp/classtest"
        @@tmpfiles << file

        assert(FileTest.exists?(file))

        obj = nil
        assert_nothing_raised {
            obj = Puppet::Type::PFile[file]
        }

        assert_nothing_raised {
            assert_equal(%w{puppet[top] testing[testingname] component[componentname] /tmp/classtest}, obj.path)
            #Puppet.err obj.path
        }

        assert_nothing_raised {
            trans.rollback
        }
        assert(! FileTest.exists?(file))
    end

    def snippet_argumentdefaults(trans)
        file1 = "/tmp/argumenttest1"
        file2 = "/tmp/argumenttest2"
        #@@tmpfiles << file

        assert(FileTest.exists?(file1))
        assert(File.stat(file1).mode & 007777 == 0755)
        
        assert(FileTest.exists?(file2))
        assert(File.stat(file2).mode & 007777 == 0644)
    end

    def snippet_casestatement(trans)
        files = %w{
            /tmp/existsfile
            /tmp/existsfile2
            /tmp/existsfile3
        }

        files.each { |file|
            assert(FileTest.exists?(file), "File %s is missing" % file)
            assert(File.stat(file).mode & 007777 == 0755, "File %s is not 755" % file)
        }

        assert_nothing_raised {
            trans.rollback
        }
    end

    def disabled_snippet_dirchmod(trans)
        dirs = %w{a b}.collect { |letter|
            "/tmp/dirchmodtest%s" % letter
        }

        @@tmpfiles << dirs

        dirs.each { |dir|
            assert(FileTest.directory?(dir))
        }

        assert(File.stat("/tmp/dirchmodtesta").mode & 007777 == 0755)
        assert(File.stat("/tmp/dirchmodtestb").mode & 007777 == 0700)

        assert_nothing_raised {
            trans.rollback
        }
    end

    # XXX this is the answer
    Dir.entries($snippetbase).sort.each { |file|
        next if file =~ /^\./

        mname = "snippet_" + file
        if self.method_defined?(mname)
            #eval("alias %s %s" % [testname, mname])
            testname = ("test_" + mname).intern
            self.send(:define_method, testname) {
                # first parse the file
                server = Puppet::Server::Master.new(
                    :File => File.join($snippetbase, file),
                    :Local => true
                )
                client = Puppet::Client::MasterClient.new(
                    :Master => server,
                    :Cache => false
                )

                assert(client.local)
                assert_nothing_raised {
                    client.getconfig()
                }
                trans = nil
                assert_nothing_raised {
                    trans = client.config()
                }
                assert_nothing_raised {
                    self.send(mname, trans)
                }
            }
            mname = mname.intern
            #eval("alias %s %s" % [testname, mname])
        end
    }
end
