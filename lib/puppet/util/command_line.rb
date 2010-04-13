module Puppet
    module Util
        module CommandLine
            def self.shift_subcommand_from_argv( argv = ARGV, stdin = STDIN )
                if ! argv.first
                    "main" unless stdin.tty? # ttys get usage info
                elsif argv.first =~ /^-|\.pp$|\.rb$/
                    "main"
                else
                    argv.shift
                end
            end
        end
    end
end
