module PuppetTest::ResourceTesting
    Parser = Puppet::Parser
    AST = Puppet::Parser::AST
    def mkclassframing(interp = nil)
        interp ||= mkinterp

        interp.newdefine("resource", :arguments => [%w{one}, %w{two value}, %w{three}])
        interp.newclass("")
        source = interp.newclass("base")
        interp.newclass("sub1", :parent => "base")
        interp.newclass("sub2", :parent => "base")
        interp.newclass("other")

        scope = Parser::Scope.new(:interp => interp)
        scope.source = source

        return interp, scope, source
    end

    def mkevaltest(interp = nil)
        interp ||= mkinterp
        @interp.newdefine("evaltest",
            :arguments => [%w{one}, ["two", stringobj("755")]],
            :code => resourcedef("file", "/tmp",
                "owner" => varref("one"), "mode" => varref("two"))
        )
    end

    def mkresource(args = {})

        if args[:scope] and ! args[:source]
            args[:source] = args[:scope].source
        end

        unless args[:scope]
            unless defined? @scope
                raise "Must set @scope to mkresource"
            end
        end

        {:type => "resource", :title => "testing",
            :source => @source, :scope => @scope}.each do |param, value|
                args[param] ||= value
        end

        unless args[:source].is_a?(Puppet::Parser::AST::HostClass)
            args[:source] = args[:scope].findclass(args[:source])
        end

        params = args[:params] || {:one => "yay", :three => "rah"}
        if args[:params] == :none
            args.delete(:params)
        else
            args[:params] = paramify args[:source], params
        end

        Parser::Resource.new(args)
    end

    def param(name, value, source)
        Parser::Resource::Param.new(:name => name, :value => value, :source => source)
    end

    def paramify(source, hash)
        hash.collect do |name, value|
            Parser::Resource::Param.new(
                :name => name, :value => value, :source => source
            )
        end
    end
end

# $Id$
