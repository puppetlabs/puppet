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
        return Puppet::Parser::Compile.new(node, parser(node.environment), :ast_nodes => usenodes?).compile
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
            parser = Puppet::Parser::Parser.new(:environment => environment)
            if self.code
                parser.string = self.code
            elsif self.file
                parser.file = self.file
            else
                file = Puppet.config.value(:manifest, environment)
                parser.file = file
            end
            parser.parse
            return parser
        rescue => detail
            if Puppet[:trace]
                puts detail.backtrace
            end
            msg = "Could not parse"
            if environment and environment != ""
                msg += " for environment %s" % environment
            end
            msg += ": %s" % detail
            raise Puppet::Error, detail
        end
    end

    # Return the parser for a specific environment.
    def parser(environment)
        if ! @parsers[environment] or @parsers[environment].reparse?
            # This will throw an exception if it does not succeed.  We only
            # want to get rid of the old parser if we successfully create a new
            # one.
            begin
                tmp = create_parser(environment)
                @parsers[environment].clear if @parsers[environment]
                @parsers[environment] = tmp
            rescue
                # Nothing, yo.
            end
        end
        @parsers[environment]
    end
end
