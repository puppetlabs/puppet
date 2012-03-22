module Puppet
  module Util
    class CommandLine

      class PuppetOptionError < Puppet::Error
      end

      class PuppetUnrecognizedOptionError < PuppetOptionError
      end

      # This is a command line option parser.  It is intended to have an API that is very similar to
      #  the ruby stdlib 'OptionParser' API, for ease of integration into our existing code... however,
      #  However, we've removed the OptionParser-based implementation and are only maintaining the
      #  it's impilemented based on the third-party "trollop" library.  This was done because there
      #  are places where the stdlib OptionParser is not flexible enough to meet our needs.

      class PuppetOptionParser
        def initialize(usage_msg = nil)
          require "puppet/util/command_line/trollop"

          @create_default_short_options = false

          @wrapped_parser = ::Trollop::Parser.new do
            banner usage_msg
            create_default_short_options = false
            handle_help_and_version = false
          end

        end

        # This parameter, if set, will tell the underlying option parser not to throw an
        #  exception if we pass it options that weren't explicitly registered.  We need this
        #  capability because we need to be able to pass all of the command-line options before
        #  we know which application/face they are going to be running, but the app/face
        #  may specify additional command-line arguments that are valid for that app/face.
        attr_reader :ignore_invalid_options

        def ignore_invalid_options=(value)
          @wrapped_parser.ignore_invalid_options = value
        end


        def on(*args, &block)
          # This is ugly and I apologize :)
          # I wanted to keep the API for this class compatible with how we were previously
          #  interacting with the ruby stdlib OptionParser.  Unfortunately, that means that
          #  you can specify options as an array, with three or four elements.  The 2nd element
          #  is an optional "short" representation.  This series of shift/pop operations seemed
          #  the easiest way to avoid breaking compatibility with that syntax.

          # The first argument is always the "--long" representation...
          long = args.shift

          # The last argument is always the "type"
          type = args.pop
          # The second-to-last argument is always the "description"
          desc = args.pop

          # if there is anything left, it's the "short" representation.
          short = args.shift

          options = {
              :long => long,
              :short => short,
              :required => false,
              :callback => block,
          }

          case type
            when :REQUIRED
              options[:type] = :string
            when :NONE
              options[:type] = :flag
            else
              raise PuppetOptionError.new("Unsupported type: '#{type}'")
          end

          @wrapped_parser.opt long.sub("^--", "").intern, desc, options
        end

        def parse(*args)
          args = args[0] if args.size == 1 and Array === args[0]
          args_copy = args.dup
          begin
            @wrapped_parser.parse args_copy
          rescue ::Trollop::CommandlineError => err
            raise PuppetUnrecognizedOptionError.new(err) if err.message =~ /^unknown argument/
          end
        end
      end


    end
  end
end