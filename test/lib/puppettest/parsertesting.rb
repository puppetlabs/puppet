require 'puppettest'
require 'puppet/rails'

module PuppetTest::ParserTesting
    include PuppetTest
    AST = Puppet::Parser::AST

    Compiler = Puppet::Parser::Compiler

    # A fake class that we can use for testing evaluation.
    class FakeAST
        attr_writer :evaluate

        def evaluated?
            defined? @evaluated and @evaluated
        end

        def evaluate(*args)
            @evaluated = true
            return @evaluate
        end

        def initialize(val = nil)
            if val
                @evaluate = val
            end
        end

        def reset
            @evaluated = nil
        end

        def safeevaluate(*args)
            evaluate()
        end

        def evaluate_match(othervalue, scope, options={})
            value = evaluate()
            othervalue == value
        end
    end

    def astarray(*args)
        AST::ASTArray.new(
            :children => args
        )
    end

    def mkcompiler(parser = nil)
        node = mknode
        return Compiler.new(node)
    end

    def mknode(name = nil)
        require 'puppet/node'
        Puppet::Node.new(name || "nodename")
    end

    def mkparser
        Puppet::Node::Environment.clear
        Puppet::Parser::Parser.new(Puppet::Node::Environment.new)
    end

    def mkscope(hash = {})
        parser ||= mkparser
        compiler ||= mkcompiler
        compiler.topscope.source = (parser.find_hostclass("", "") || parser.newclass(""))

        unless compiler.topscope.source
            raise "Could not find source for scope"
        end
        # Make the 'main' stuff
        compiler.send(:evaluate_main)
        compiler.topscope
    end

    def classobj(name, hash = {})
        hash[:file] ||= __FILE__
        hash[:line] ||= __LINE__
        hash[:type] ||= name
        AST::HostClass.new(hash)
    end

    def tagobj(*names)
        args = {}
        newnames = names.collect do |name|
            if name.is_a? AST
                name
            else
                nameobj(name)
            end
        end
        args[:type] = astarray(*newnames)
        assert_nothing_raised("Could not create tag %s" % names.inspect) {
            return AST::Tag.new(args)
        }
    end

    def resourcedef(type, title, params)
        unless title.is_a?(AST)
            title = stringobj(title)
        end
        assert_nothing_raised("Could not create %s %s" % [type, title]) {
            return AST::Resource.new(
                :file => __FILE__,
                :line => __LINE__,
                :title => title,
                :type => type,
                :parameters => resourceinst(params)
            )
        }
    end

    def virt_resourcedef(*args)
        res = resourcedef(*args)
        res.virtual = true
        res
    end

    def resourceoverride(type, title, params)
        assert_nothing_raised("Could not create %s %s" % [type, name]) {
            return AST::ResourceOverride.new(
                :file => __FILE__,
                :line => __LINE__,
                :object => resourceref(type, title),
                :type => type,
                :parameters => resourceinst(params)
            )
        }
    end

    def resourceref(type, title)
        assert_nothing_raised("Could not create %s %s" % [type, title]) {
            return AST::ResourceReference.new(
                :file => __FILE__,
                :line => __LINE__,
                :type => type,
                :title => stringobj(title)
            )
        }
    end

    def fileobj(path, hash = {"owner" => "root"})
        assert_nothing_raised("Could not create file %s" % path) {
            return resourcedef("file", path, hash)
        }
    end

    def nameobj(name)
        assert_nothing_raised("Could not create name %s" % name) {
            return AST::Name.new(
                                 :file => tempfile(),
                                 :line => rand(100),
                                 :value => name
                                )
        }
    end

    def typeobj(name)
        assert_nothing_raised("Could not create type %s" % name) {
            return AST::Type.new(
                                 :file => tempfile(),
                                 :line => rand(100),
                                 :value => name
                                )
        }
    end

    def nodedef(name)
        assert_nothing_raised("Could not create node %s" % name) {
            return AST::NodeDef.new(
                :file => tempfile(),
                :line => rand(100),
                :names => nameobj(name),
                :code => AST::ASTArray.new(
                    :children => [
                        varobj("%svar" % name, "%svalue" % name),
                        fileobj("/%s" % name)
                    ]
                )
            )
        }
    end

    def resourceinst(hash)
        assert_nothing_raised("Could not create resource instance") {
            params = hash.collect { |param, value|
            resourceparam(param, value)
        }
        return AST::ResourceInstance.new(
                                   :file => tempfile(),
                                   :line => rand(100),
                                   :children => params
                                  )
        }
    end

    def resourceparam(param, value)
        # Allow them to pass non-strings in
        if value.is_a?(String)
            value = stringobj(value)
        end
        assert_nothing_raised("Could not create param %s" % param) {
            return AST::ResourceParam.new(
                                        :file => tempfile(),
                                        :line => rand(100),
                                        :param => param,
                                        :value => value
                                       )
        }
    end

    def stringobj(value)
        AST::String.new(
                        :file => tempfile(),
                        :line => rand(100),
                        :value => value
                       )
    end

    def varobj(name, value)
        unless value.is_a? AST
            value = stringobj(value)
        end
        assert_nothing_raised("Could not create %s code" % name) {
            return AST::VarDef.new(
                                   :file => tempfile(),
                                   :line => rand(100),
                                   :name => nameobj(name),
                                   :value => value
                                  )
        }
    end

    def varref(name)
        assert_nothing_raised("Could not create %s variable" % name) {
            return AST::Variable.new(
                                     :file => __FILE__,
                                     :line => __LINE__,
                                     :value => name
                                    )
        }
    end

    def argobj(name, value)
        assert_nothing_raised("Could not create %s compargument" % name) {
            return AST::CompArgument.new(
                                         :children => [nameobj(name), stringobj(value)]
                                        )
        }
    end

    def defaultobj(type, params)
        pary = []
        params.each { |p,v|
            pary << AST::ResourceParam.new(
                                         :file => __FILE__,
                                         :line => __LINE__,
                                         :param => p,
                                         :value => stringobj(v)
                                        )
        }
        past = AST::ASTArray.new(
                                 :file => __FILE__,
                                 :line => __LINE__,
                                 :children => pary
                                )

        assert_nothing_raised("Could not create defaults for %s" % type) {
            return AST::ResourceDefaults.new(
                :file => __FILE__,
                :line => __LINE__,
                :type => type,
                :parameters => past
            )
        }
    end

    def taggedobj(name, ftype = :statement)
        functionobj("tagged", name, ftype)
    end

    def functionobj(function, name, ftype = :statement)
        func = nil
        assert_nothing_raised do
            func = Puppet::Parser::AST::Function.new(
                :name => function,
                :ftype => ftype,
                :arguments => AST::ASTArray.new(
                    :children => [nameobj(name)]
                )
            )
        end

        return func
    end

    # This assumes no nodes
    def assert_creates(manifest, *files)
        interp = nil
        oldmanifest = Puppet[:manifest]
        Puppet[:manifest] = manifest

        trans = nil
        assert_nothing_raised {
            trans = Puppet::Parser::Compiler.new(mknode).compile
        }

        config = nil
        assert_nothing_raised {
            config = trans.extract.to_catalog
        }

        config.apply

        files.each do |file|
            assert(FileTest.exists?(file), "Did not create %s" % file)
        end
    ensure
        Puppet[:manifest] = oldmanifest
    end

    def mk_transobject(file = "/etc/passwd")
        obj = nil
        assert_nothing_raised {
            obj = Puppet::TransObject.new("file", file)
            obj["owner"] = "root"
            obj["mode"] = "644"
        }

        return obj
    end

    def mk_transbucket(*resources)
        bucket = nil
        assert_nothing_raised {
            bucket = Puppet::TransBucket.new
            bucket.name = "yayname"
            bucket.type = "yaytype"
        }

        resources.each { |o| bucket << o }

        return bucket
    end

    # Make a tree of resources, yielding if desired
    def mk_transtree(depth = 4, width = 2)
        top = nil
        assert_nothing_raised {
            top = Puppet::TransBucket.new
            top.name = "top"
            top.type = "bucket"
        }

        bucket = top

        file = tempfile()
        depth.times do |i|
            resources = []
            width.times do |j|
                path = tempfile + i.to_s
                obj = Puppet::TransObject.new("file", path)
                obj["owner"] = "root"
                obj["mode"] = "644"

                # Yield, if they want
                if block_given?
                    yield(obj, i, j)
                end

                resources << obj
            end

            newbucket = mk_transbucket(*resources)

            bucket.push newbucket
            bucket = newbucket
        end

        return top
    end

    # Take a list of AST resources, evaluate them, and return the results
    def assert_evaluate(children)
        top = nil
        assert_nothing_raised("Could not create top object") {
            top = AST::ASTArray.new(
                :children => children
            )
        }

        trans = nil
        scope = nil
        assert_nothing_raised {
            scope = Puppet::Parser::Scope.new()
            trans = scope.evaluate(:ast => top)
        }

        return trans
    end
end
