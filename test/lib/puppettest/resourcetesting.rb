module PuppetTest::ResourceTesting
    Parser = Puppet::Parser
    AST = Puppet::Parser::AST
    def mkclassframing(parser = nil)
        parser ||= mkparser

        parser.newdefine("resource", :arguments => [%w{one}, %w{two value}, %w{three}])
        parser.newclass("")
        source = parser.newclass("base")
        parser.newclass("sub1", :parent => "base")
        parser.newclass("sub2", :parent => "base")
        parser.newclass("other")

        config = mkconfig(:parser => parser)
        config.topscope.source = source

        return parser, config.topscope, source
    end

    def mkevaltest(parser = nil)
        parser ||= mkparser
        @parser.newdefine("evaltest",
            :arguments => [%w{one}, ["two", stringobj("755")]],
            :code => resourcedef("file", "/tmp",
                "owner" => varref("one"), "mode" => varref("two"))
        )
    end

    def mkresource(args = {})
        args[:source] ||= "source"
        args[:scope] ||= stub :tags => []

        {:type => "resource", :title => "testing",
            :source => "source", :scope => "scope"}.each do |param, value|
                args[param] ||= value
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
