module Puppet
  module Util
    module CommandLineUtils
      class RubyStdLibPuppetOptionParser
        def initialize(usage_msg = nil)
          @wrapped_parser = OptionParser.new(usage_msg)
        end

        attr_accessor :ignore_invalid_options

        def on(*args, &block)
          @wrapped_parser.on(*args, &block)
        end

        def parse(*args)
          if (ignore_invalid_options)
            args = args[0] if args.size == 1 and Array === args[0]

            # TODO cprice: document this crappy hack
            args_copy = args.dup
            while (args_copy.length > 0)
              begin
                @wrapped_parser.parse!(args_copy)
                break
              rescue OptionParser::InvalidOption => err
                # the parser is deleting args from the array for us, we just need to ignore it when it hits an
                #  invalid one.
              end
            end
          else
            begin
              @wrapped_parser.parse(*args)
            rescue OptionParser::InvalidOption => err
              raise PuppetOptionError.new(err)
            end

          end

        end

      end
    end
  end
end
