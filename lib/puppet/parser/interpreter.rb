require 'puppet'
require 'timeout'
require 'puppet/rails'
require 'puppet/util/methodhelper'
require 'puppet/parser/parser'
require 'puppet/parser/compiler'
require 'puppet/parser/scope'

# The interpreter is a very simple entry-point class that
# manages the existence of the parser (e.g., replacing it
# when files are reparsed).  You can feed it a node and
# get the node's catalog back.
class Puppet::Parser::Interpreter
    include Puppet::Util

    attr_accessor :usenodes

    include Puppet::Util::Errors

    # Determine the configuration version for a given node's environment.
    def configuration_version(node)
        parser(node.environment).version
    end

    # evaluate our whole tree
    def compile(node)
        raise Puppet::ParseError, "Could not parse configuration; cannot compile on node %s" % node.name unless env_parser = parser(node.environment)
        begin
            return Puppet::Parser::Compiler.new(node, env_parser).compile.to_resource
        rescue => detail
            puts detail.backtrace if Puppet[:trace]
            raise Puppet::Error, detail.to_s + " on node %s" % node.name
        end
    end

    # create our interpreter
    def initialize
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

    # Return the parser for a specific environment.
    def parser(environment)
        if ! @parsers[environment] or @parsers[environment].reparse?
            # This will throw an exception if it does not succeed.
            @parsers[environment] = create_parser(environment)
        end
        @parsers[environment]
    end

    private

    # Create a new parser object and pre-parse the configuration.
    def create_parser(environment)
        begin
            parser = Puppet::Parser::Parser.new(:environment => environment)
            if code = Puppet.settings.uninterpolated_value(:code, environment) and code != ""
                parser.string = code
            else
                file = Puppet.settings.value(:manifest, environment)
                parser.file = file
            end
            parser.parse
            return parser
        rescue => detail
            msg = "Could not parse"
            if environment and environment != ""
                msg += " for environment %s" % environment
            end
            msg += ": %s" % detail.to_s
            error = Puppet::Error.new(msg)
            error.set_backtrace(detail.backtrace)
            raise error
        end
    end
end
