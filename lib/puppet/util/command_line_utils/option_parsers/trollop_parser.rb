module Puppet
  module Util
    module CommandLineUtils
      class TrollopPuppetOptionParser
        def initialize(usage_msg = nil)
          # I hate these (inline requires)... but I'm doing it anyway until we have a better pattern for this.
          require "puppet/util/command_line_utils/lib_trollop"

          @create_default_short_options = false

          @wrapped_parser = ::Trollop::Parser.new do
            banner usage_msg
            create_default_short_options = false
            handle_help_and_version = false
          end

        end

        attr_reader :ignore_invalid_options

        def ignore_invalid_options=(value)
          @wrapped_parser.ignore_invalid_options = value
        end


        def on(*args, &block)
          # TODO cprice: docs
          long = args.shift
          type = args.pop
          desc = args.pop
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

