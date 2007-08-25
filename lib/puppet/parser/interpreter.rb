require 'puppet'
require 'timeout'
require 'puppet/rails'
require 'puppet/util/methodhelper'
require 'puppet/parser/parser'
require 'puppet/parser/compile'
require 'puppet/parser/scope'

# The interpreter is a very simple entry-point class that
# manages the existence of the parser (e.g., replacing it
# when files are reparsed).  You can feed it a node and
# get the node's configuration back.
class Puppet::Parser::Interpreter
    include Puppet::Util

    attr_accessor :usenodes
    attr_accessor :code, :file

    include Puppet::Util::Errors

    # Determine the configuration version for a given node's environment.
    def configuration_version(node)
        parser(node.environment).version
    end

    # evaluate our whole tree
    def compile(node)
        return Puppet::Parser::Configuration.new(node, parser(node.environment), :ast_nodes => usenodes?).compile
    end

    # create our interpreter
    def initialize(options = {})
        if @code = options[:Code]
        elsif @file = options[:Manifest]
        end

        if options.include?(:UseNodes)
            @usenodes = options[:UseNodes]
        else
            @usenodes = true
        end

        # The class won't always be defined during testing.
        if Puppet[:storeconfigs] 
            if Puppet.features.rails?
                Puppet::Rails.init
            else
                raise Puppet::Error, "Rails is missing; cannot store configurations"
            end
        end

        @parsers = {}
    end

    # Should we parse ast nodes?
    def usenodes?
        defined?(@usenodes) and @usenodes
    end

    private

    # Create a new parser object and pre-parse the configuration.
    def create_parser(environment)
        begin
            parser = Puppet::Parser::Parser.new(environment)
            if self.code
                parser.string = self.code
            elsif self.file
                parser.file = self.file
            end
            parser.parse
            return parser
        rescue => detail
            if Puppet[:trace]
                puts detail.backtrace
            end
            Puppet.err "Could not parse for environment %s: %s" % [environment, detail]
            return nil
        end
    end

    # Return the parser for a specific environment.
    def parser(environment)
        if ! @parsers[environment] or @parsers[environment].reparse?
            if tmp = create_parser(environment)
                @parsers[environment].clear if @parsers[environment]
                @parsers[environment] = tmp
            end
            unless @parsers[environment]
                raise Puppet::Error, "Could not parse any configurations"
            end
        end
        @parsers[environment]
    end
end
