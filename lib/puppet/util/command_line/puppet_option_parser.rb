require 'puppet/util/command_line/trollop'

module Puppet
  module Util
    class CommandLine
      class PuppetOptionError < Puppet::Error
      end

      class TrollopCommandlineError < Puppet::Util::CommandLine::Trollop::CommandlineError; end

      # This is a command line option parser.  It is intended to have an API that is very similar to
      #  the ruby stdlib 'OptionParser' API, for ease of integration into our existing code... however,
      #  However, we've removed the OptionParser-based implementation and are only maintaining the
      #  it's implemented based on the third-party "trollop" library.  This was done because there
      #  are places where the stdlib OptionParser is not flexible enough to meet our needs.

      class PuppetOptionParser
        def initialize(usage_msg = nil)
          require "puppet/util/command_line/trollop"

          @create_default_short_options = false

          @parser = Trollop::Parser.new do
            banner usage_msg
          end

        end

        # This parameter, if set, will tell the underlying option parser not to throw an
        #  exception if we pass it options that weren't explicitly registered.  We need this
        #  capability because we need to be able to pass all of the command-line options before
        #  we know which application/face they are going to be running, but the app/face
        #  may specify additional command-line arguments that are valid for that app/face.
        attr_reader :ignore_invalid_options

        def ignore_invalid_options=(value)
          @parser.ignore_invalid_options = value
        end

        def on(*args, &block)
          # The 2nd element is an optional "short" representation.
          if args.length == 3
            long, desc, type = args
          elsif args.length == 4
            long, short, desc, type = args
          else
            raise ArgumentError, _("this method only takes 3 or 4 arguments. Given: %{args}") % { args: args.inspect }
          end

          options = {
              :long => long,
              :short => short,
              :required => false,
              :callback => pass_only_last_value_on_to(block),
              :multi => true,
          }

          case type
            when :REQUIRED
              options[:type] = :string
            when :NONE
              options[:type] = :flag
            else
              raise PuppetOptionError.new(_("Unsupported type: '%{type}'") % { type: type })
          end

          @parser.opt long.sub("^--", "").intern, desc, options
        end

        def parse(*args)
          args = args[0] if args.size == 1 and Array === args[0]
          args_copy = args.dup
          begin
            @parser.parse args_copy
          rescue Puppet::Util::CommandLine::Trollop::CommandlineError => err
            raise PuppetOptionError.new(_("Error parsing arguments"), err)
          end
        end

        def pass_only_last_value_on_to(block)
          lambda { |values| block.call(values.is_a?(Array) ? values.last : values) }
        end
        private :pass_only_last_value_on_to
      end
    end
  end
end
