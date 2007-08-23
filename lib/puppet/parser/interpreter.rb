require 'puppet'
require 'timeout'
require 'puppet/rails'
require 'puppet/util/methodhelper'
require 'puppet/parser/parser'
require 'puppet/parser/configuration'
require 'puppet/parser/scope'

# The interpreter is a very simple entry-point class that
# manages the existence of the parser (e.g., replacing it
# when files are reparsed).  You can feed it a node and
# get the node's configuration back.
class Puppet::Parser::Interpreter
    include Puppet::Util

    attr_accessor :usenodes
    attr_reader :parser

    include Puppet::Util::Errors

    # create our interpreter
    def initialize(hash)
        if @code = hash[:Code]
            @file = nil # to avoid warnings
        elsif ! @file = hash[:Manifest]
            devfail "You must provide code or a manifest"
        end

        if hash.include?(:UseNodes)
            @usenodes = hash[:UseNodes]
        else
            @usenodes = true
        end

        # By default, we only search for parsed nodes.
        @nodesource = :code

        @setup = false

        @local = hash[:Local] || false

        # The class won't always be defined during testing.
        if Puppet[:storeconfigs] 
            if Puppet.features.rails?
                Puppet::Rails.init
            else
                raise Puppet::Error, "Rails is missing; cannot store configurations"
            end
        end

        @files = []

        # Create our parser object
        parsefiles
    end

    def parsedate
        parsefiles()
        @parsedate
    end

    # evaluate our whole tree
    def compile(node)
        parsefiles()

        return Puppet::Parser::Configuration.new(node, @parser, :ast_nodes => @usenodes).compile
    end

    private

    # Check whether any of our files have changed.
    def checkfiles
        if @files.find { |f| f.changed?  }
            @parsedate = Time.now.to_i
        end
    end

    # Parse the files, generating our parse tree.  This automatically
    # reparses only if files are updated, so it's safe to call multiple
    # times.
    def parsefiles
        # First check whether there are updates to any non-puppet files
        # like templates.  If we need to reparse, this will get quashed,
        # but it needs to be done first in case there's no reparse
        # but there are other file changes.
        checkfiles()

        # Check if the parser should reparse.
        if @file
            if defined? @parser
                if stamp = @parser.reparse?
                    Puppet.notice "Reloading files"
                else
                    return false
                end
            end

            unless FileTest.exists?(@file)
                # If we've already parsed, then we're ok.
                if findclass("", "")
                    return
                else
                    raise Puppet::Error, "Manifest %s must exist" % @file
                end
            end
        end

        # Create a new parser, just to keep things fresh.  Don't replace our
        # current parser until we know weverything works.
        newparser = Puppet::Parser::Parser.new()
        if @code
            newparser.string = @code
        else
            newparser.file = @file
        end

        # Parsing stores all classes and defines and such in their
        # various tables, so we don't worry about the return.
        begin
            if @local
                newparser.parse
            else
                benchmark(:info, "Parsed manifest") do
                    newparser.parse
                end
            end
            # We've gotten this far, so it's ok to swap the parsers.
            oldparser = @parser
            @parser = newparser
            if oldparser
                oldparser.clear
            end

            # Mark when we parsed, so we can check freshness
            @parsedate = Time.now.to_i
        rescue => detail
            if Puppet[:trace]
                puts detail.backtrace
            end
            Puppet.err "Could not parse; using old configuration: %s" % detail
        end
    end
end

# $Id$
