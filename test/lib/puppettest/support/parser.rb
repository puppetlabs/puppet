module PuppetTest::Support::Parser
    AST = Puppet::Parser::AST

    def astarray(*args)
        AST::ASTArray.new(
                          :children => args
                         )
    end

    def classobj(name, args = {})
        args[:type] ||= nameobj(name)
        args[:code] ||= AST::ASTArray.new(
            :file => __FILE__,
            :line => __LINE__,
            :children => [
                varobj("%svar" % name, "%svalue" % name),
                fileobj("/%s" % name)
            ]
        )
        assert_nothing_raised("Could not create class %s" % name) {
            return AST::ClassDef.new(args)
        }
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

    def compobj(name, args = {})
        args[:file] ||= tempfile()
        args[:line] ||= rand(100)
        args[:type] ||= nameobj(name)
        args[:args] ||= AST::ASTArray.new(
                                          :file => tempfile(),
                                          :line => rand(100),
                                          :children => []
                                         )
        args[:code] ||= AST::ASTArray.new(
            :file => tempfile(),
            :line => rand(100),
            :children => [
                varobj("%svar" % name, "%svalue" % name),
                fileobj("/%s" % name)
            ]
        )
        assert_nothing_raised("Could not create compdef %s" % name) {
            return AST::CompDef.new(args)
        }
    end

    def objectdef(type, name, params)
        assert_nothing_raised("Could not create %s %s" % [type, name]) {
            return AST::ObjectDef.new(
                                      :file => __FILE__,
                                      :line => __LINE__,
                                      :name => stringobj(name),
                                      :type => nameobj(type),
                                      :params => objectinst(params)
                                     )
        }
    end

    def fileobj(path, hash = {"owner" => "root"})
        assert_nothing_raised("Could not create file %s" % path) {
            return objectdef("file", path, hash)
            #            return AST::ObjectDef.new(
            #                :file => tempfile(),
            #                :line => rand(100),
            #                :name => stringobj(path),
            #                :type => nameobj("file"),
            #                :params => objectinst(hash)
            #            )
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

    def objectinst(hash)
        assert_nothing_raised("Could not create object instance") {
            params = hash.collect { |param, value|
            objectparam(param, value)
        }
        return AST::ObjectInst.new(
                                   :file => tempfile(),
                                   :line => rand(100),
                                   :children => params
                                  )
        }
    end

    def objectparam(param, value)
        # Allow them to pass non-strings in
        if value.is_a?(String)
            value = stringobj(value)
        end
        assert_nothing_raised("Could not create param %s" % param) {
            return AST::ObjectParam.new(
                                        :file => tempfile(),
                                        :line => rand(100),
                                        :param => nameobj(param),
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
            pary << AST::ObjectParam.new(
                                         :file => __FILE__,
                                         :line => __LINE__,
                                         :param => nameobj(p),
                                         :value => stringobj(v)
                                        )
        }
        past = AST::ASTArray.new(
                                 :file => __FILE__,
                                 :line => __LINE__,
                                 :children => pary
                                )

        assert_nothing_raised("Could not create defaults for %s" % type) {
            return AST::TypeDefaults.new(
                :file => __FILE__,
                :line => __LINE__,
                :type => typeobj(type),
                :params => past
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
        assert_nothing_raised {
            interp = Puppet::Parser::Interpreter.new(
                                                     :Manifest => manifest,
                                                     :UseNodes => false
                                                    )
        }

        config = nil
        assert_nothing_raised {
            config = interp.run(Facter["hostname"].value, {})
        }

        comp = nil
        assert_nothing_raised {
            comp = config.to_type
        }

        assert_apply(comp)

        files.each do |file|
            assert(FileTest.exists?(file), "Did not create %s" % file)
        end
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

    def mk_transbucket(*objects)
        bucket = nil
        assert_nothing_raised {
            bucket = Puppet::TransBucket.new
            bucket.name = "yayname"
            bucket.type = "yaytype"
        }

        objects.each { |o| bucket << o }

        return bucket
    end

    # Make a tree of objects, yielding if desired
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
            objects = []
            width.times do |j|
                path = tempfile + i.to_s
                obj = Puppet::TransObject.new("file", path)
                obj["owner"] = "root"
                obj["mode"] = "644"

                # Yield, if they want
                if block_given?
                    yield(obj, i, j)
                end

                objects << obj
            end

            newbucket = mk_transbucket(*objects)

            bucket.push newbucket
            bucket = newbucket
        end

        return top
    end

    # Take a list of AST objects, evaluate them, and return the results
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

# $Id$
