#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppet/parser/interpreter'
require 'puppet/parser/parser'
require 'puppet/network/client'
require 'puppet/network/handler'
require 'puppettest'

class TestSnippets < Test::Unit::TestCase
	include PuppetTest
    include ObjectSpace

    def self.snippetdir
        PuppetTest.datadir "snippets"
    end

    def snippet(name)
        File.join(self.class.snippetdir, name)
    end
    
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
        Puppet::Network::Client.new(args)
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

    def properties(type)
        properties = type.validproperties
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
        type.parameters.each { |name,property|
            params.push name
        }

        params
    end

    def randthing(thing,type)
        list = self.send(thing,type)
        list[rand(list.length)]
    end

    def randeach(type)
        [:properties, :metaparams, :params].collect { |thing|
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

    # this is here in case no tests get defined; otherwise we get a warning
    def test_nothing
    end

    def snippet_filecreate
        %w{a b c d}.each { |letter|
            file = "/tmp/create%stest" % letter
            Puppet.info "testing %s" % file
            assert(Puppet.type(:file)[file], "File %s does not exist" % file)
            assert(FileTest.exists?(file))
            @@tmpfiles << file
        }
        %w{a b}.each { |letter|
            file = "/tmp/create%stest" % letter
            assert(File.stat(file).mode & 007777 == 0755)
        }
    end

    def snippet_simpledefaults
        file = "/tmp/defaulttest"
        @@tmpfiles << file
        assert(FileTest.exists?(file), "File %s does not exist" % file)
        assert(File.stat(file).mode & 007777 == 0755)
    end

    def snippet_simpleselector
        files = %w{a b c d}.collect { |letter|
            "/tmp/snippetselect%stest" % letter
        }
        @@tmpfiles += files

        files.each { |file|
            assert(FileTest.exists?(file), "File %s does not exist" % file)
            assert(File.stat(file).mode & 007777 == 0755,
                "File %s is the incorrect mode" % file)
            @@tmpfiles << file
        }
    end

    def snippet_classpathtest
        file = "/tmp/classtest"
        @@tmpfiles << file

        assert(FileTest.exists?(file))

        obj = nil
        assert_nothing_raised {
            obj = Puppet.type(:file)[file]
        }

        assert_nothing_raised {
            assert_equal(
                "//testing/component[componentname]/File[/tmp/classtest]",
                obj.path)
            #Puppet.err obj.path
        }
    end

    def snippet_argumentdefaults
        file1 = "/tmp/argumenttest1"
        file2 = "/tmp/argumenttest2"
        @@tmpfiles << file1
        @@tmpfiles << file2

        assert(FileTest.exists?(file1))
        assert(File.stat(file1).mode & 007777 == 0755)
        
        assert(FileTest.exists?(file2))
        assert(File.stat(file2).mode & 007777 == 0644)
    end

    def snippet_casestatement
        files = %w{
            /tmp/existsfile
            /tmp/existsfile2
            /tmp/existsfile3
            /tmp/existsfile4
            /tmp/existsfile5
        }

        files.each { |file|
            assert(FileTest.exists?(file), "File %s is missing" % file)
            assert(File.stat(file).mode & 007777 == 0755, "File %s is not 755" % file)
        }
    end

    def snippet_implicititeration
        files = %w{a b c d e f g h}.collect { |l| "/tmp/iteration%stest" % l }

        files.each { |file|
            @@tmpfiles << file
            assert(FileTest.exists?(file), "File %s does not exist" % file)
            assert(File.stat(file).mode & 007777 == 0755,
                "File %s is not 755" % file)

        }
    end

    def snippet_multipleinstances
        files = %w{a b c}.collect { |l| "/tmp/multipleinstances%s" % l }

        files.each { |file|
            @@tmpfiles << file
            assert(FileTest.exists?(file), "File %s does not exist" % file)
            assert(File.stat(file).mode & 007777 == 0755,
                "File %s is not 755" % file)

        }
    end

    def snippet_namevartest
        file = "/tmp/testfiletest"
        dir = "/tmp/testdirtest"
        @@tmpfiles << file
        @@tmpfiles << dir
        assert(FileTest.file?(file), "File %s does not exist" % file)
        assert(FileTest.directory?(dir), "Directory %s does not exist" % dir)
    end

    def snippet_scopetest
        file = "/tmp/scopetest"
        @@tmpfiles << file
        assert(FileTest.file?(file), "File %s does not exist" % file)
        assert(File.stat(file).mode & 007777 == 0755,
            "File %s is not 755" % file)
    end

    def snippet_failmissingexecpath
        file = "/tmp/exectesting1"
        execfile = "/tmp/execdisttesting"
        @@tmpfiles << file
        @@tmpfiles << execfile
        assert(!FileTest.exists?(execfile), "File %s exists" % execfile)
    end

    def snippet_selectorvalues
        nums = %w{1 2 3 4 5}
        files = nums.collect { |n|
            "/tmp/selectorvalues%s" % n
        }

        files.each { |f|
            @@tmpfiles << f
            assert(FileTest.exists?(f), "File %s does not exist" % f)
            assert(File.stat(f).mode & 007777 == 0755,
                "File %s is not 755" % f)
        }
    end

    def snippet_singleselector
        nums = %w{1 2 3}
        files = nums.collect { |n|
            "/tmp/singleselector%s" % n
        }

        files.each { |f|
            @@tmpfiles << f
            assert(FileTest.exists?(f), "File %s does not exist" % f)
            assert(File.stat(f).mode & 007777 == 0755,
                "File %s is not 755" % f)
        }
    end

    def snippet_falsevalues
        file = "/tmp/falsevaluesfalse"
        @@tmpfiles << file
        assert(FileTest.exists?(file), "File %s does not exist" % file)
    end

    def disabled_snippet_classargtest
        [1,2].each { |num|
            file = "/tmp/classargtest%s" % num
            @@tmpfiles << file
            assert(FileTest.file?(file), "File %s does not exist" % file)
            assert(File.stat(file).mode & 007777 == 0755,
                "File %s is not 755" % file)
        }
    end

    def snippet_classheirarchy
        [1,2,3].each { |num|
            file = "/tmp/classheir%s" % num
            @@tmpfiles << file
            assert(FileTest.file?(file), "File %s does not exist" % file)
            assert(File.stat(file).mode & 007777 == 0755,
                "File %s is not 755" % file)
        }
    end

    def snippet_singleary
        [1,2,3,4].each { |num|
            file = "/tmp/singleary%s" % num
            @@tmpfiles << file
            assert(FileTest.file?(file), "File %s does not exist" % file)
        }
    end

    def snippet_classincludes
        [1,2,3].each { |num|
            file = "/tmp/classincludes%s" % num
            @@tmpfiles << file
            assert(FileTest.file?(file), "File %s does not exist" % file)
            assert(File.stat(file).mode & 007777 == 0755,
                "File %s is not 755" % file)
        }
    end

    def snippet_componentmetaparams
        ["/tmp/component1", "/tmp/component2"].each { |file|
            assert(FileTest.file?(file), "File %s does not exist" % file)
        }
    end

    def snippet_aliastest
        %w{/tmp/aliastest /tmp/aliastest2 /tmp/aliastest3}.each { |file|
            assert(FileTest.file?(file), "File %s does not exist" % file)
        }
    end

    def snippet_singlequote
        {   1 => 'a $quote',
            2 => 'some "\yayness\"'
        }.each { |count, str|
            path = "/tmp/singlequote%s" % count
            assert(FileTest.exists?(path), "File %s is missing" % path)
            text = File.read(path)

            assert_equal(str, text)
        }
    end

    # There's no way to actually retrieve the list of classes from the
    # transaction.
    def snippet_tag
        @@tmpfiles << "/tmp/settestingness"
    end

    # Make sure that set tags are correctly in place, yo.
    def snippet_tagged
        tags = {"testing" => true, "yayness" => false,
            "both" => false, "bothtrue" => true, "define" => true}

        tags.each do |tag, retval|
            @@tmpfiles << "/tmp/tagged#{tag}true"
            @@tmpfiles << "/tmp/tagged#{tag}false"

            assert(FileTest.exists?("/tmp/tagged#{tag}#{retval.to_s}"),
                "'tagged' did not return %s with %s" % [retval, tag])
        end
    end

    def snippet_defineoverrides
        file = "/tmp/defineoverrides1"
        assert(FileTest.exists?(file), "File does not exist")
        assert_equal(0755, filemode(file))
    end

    def snippet_deepclassheirarchy
        5.times { |i|
            i += 1
            file = "/tmp/deepclassheir%s" % i
            assert(FileTest.exists?(file), "File %s does not exist" % file)
        }
    end

    def snippet_emptyclass
        # There's nothing to check other than that it works
    end

    def snippet_emptyexec
        assert(FileTest.exists?("/tmp/emptyexectest"),
            "Empty exec was ignored")

        @@tmpfiles << "/tmp/emptyexextest"
    end

    def snippet_multisubs
        path = "/tmp/multisubtest"
        assert(FileTest.exists?(path), "Did not create file")
        assert_equal("sub2", File.read(path), "sub2 did not override content")
        assert_equal(0755, filemode(path), "sub1 did not override mode")
    end

    def snippet_collection
        assert(FileTest.exists?("/tmp/colltest1"), "Did not collect file")
        assert(! FileTest.exists?("/tmp/colltest2"), "Incorrectly collected file")
    end

    def snippet_virtualresources
        %w{1 2 3 4}.each do |num|
            assert(FileTest.exists?("/tmp/virtualtest#{num}"),
                "Did not collect file #{num}")
        end
    end
    
    def snippet_componentrequire
        %w{1 2}.each do |num|
            assert(FileTest.exists?("/tmp/testing_component_requires#{num}"),
                "#{num} does not exist")
            end
    end

    def snippet_realize_defined_types
        assert(FileTest.exists?("/tmp/realize_defined_test1"),
            "Did not make file from realized defined type")
        assert(FileTest.exists?("/tmp/realize_defined_test2"),
            "Did not make file from realized file inside defined type")
    end

    def snippet_fqparents
        assert(FileTest.exists?("/tmp/fqparent1"),
            "Did not make file from parent class")
        assert(FileTest.exists?("/tmp/fqparent2"),
            "Did not make file from subclass")
    end

    def snippet_fqdefinition
        assert(FileTest.exists?("/tmp/fqdefinition"),
            "Did not make file from fully-qualified definition")
    end

    def snippet_dirchmod
        dirs = %w{a b}.collect { |letter|
            "/tmp/dirchmodtest%s" % letter
        }

        @@tmpfiles << dirs

        dirs.each { |dir|
            assert(FileTest.directory?(dir))
        }

        assert(File.stat("/tmp/dirchmodtesta").mode & 007777 == 0755)
        assert(File.stat("/tmp/dirchmodtestb").mode & 007777 == 0700)
    end

    # Iterate across each of the snippets and create a test.
    Dir.entries(snippetdir).sort.each { |file|
        next if file =~ /^\./


        mname = "snippet_" + file.sub(/\.pp$/, '')
        if self.method_defined?(mname)
            #eval("alias %s %s" % [testname, mname])
            testname = ("test_" + mname).intern
            self.send(:define_method, testname) {
                # first parse the file
                server = Puppet::Network::Handler.master.new(
                    :Manifest => snippet(file),
                    :Local => true
                )
                client = Puppet::Network::Client.master.new(
                    :Master => server,
                    :Cache => false
                )

                assert(client.local)
                assert_nothing_raised {
                    client.getconfig()
                }

                client = Puppet::Network::Client.master.new(
                    :Master => server,
                    :Cache => false
                )

                assert(client.local)
                # Now do it again
                Puppet::Type.allclear
                assert_nothing_raised {
                    client.getconfig()
                }
                assert_nothing_raised {
                    trans = client.apply()
                }

                Puppet::Type.eachtype { |type|
                    type.each { |obj|
                        # don't worry about this for now
                        #unless obj.name == "puppet[top]" or
                        #    obj.is_a?(Puppet.type(:schedule))
                        #    assert(obj.parent, "%s has no parent" % obj.name)
                        #end
                        assert(obj.name)

                        if obj.is_a?(Puppet.type(:file))
                            @@tmpfiles << obj[:path]
                        end
                    }
                }
                assert_nothing_raised {
                    self.send(mname)
                }

                client.clear
            }
            mname = mname.intern
        end
    }
end

# $Id$
