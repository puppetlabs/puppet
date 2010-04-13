module Puppet
    module Util
        module CommandLine
            def self.shift_subcommand_from_argv( argv = ARGV, stdin = STDIN )
                case argv.first
                when nil;              "apply" unless stdin.tty? # ttys get usage info
                when /^-|\.pp$|\.rb$/; "apply"
                else argv.shift
                end
            end
        end
    end
end
