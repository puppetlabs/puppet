module Puppet
    module Util
        module CommandLine
            def self.subcommand_name(*args)
                subcommand_name, args = subcommand_and_args(*args)
                return subcommand_name
            end

            def self.args(*args)
                subcommand_name, args = subcommand_and_args(*args)
                return args
            end

            LegacyName = Hash.new{|h,k| k}.update({
                'agent'      => 'puppetd',
                'cert'       => 'puppetca',
                'doc'        => 'puppetdoc',
                'filebucket' => 'filebucket',
                'apply'      => 'puppet',
                'describe'   => 'pi',
                'queue'      => 'puppetqd',
                'resource'   => 'ralsh',
                'kick'       => 'puppetrun',
                'master'     => 'puppetmasterd',
            })

            def self.legacy_executable_name(*args)
                LegacyName[ subcommand_name(*args) ]
            end

            def self.subcommand_and_args( zero = $0, argv = ARGV, stdin = STDIN )
                zero = zero.gsub(/.*#{File::SEPARATOR}/,'').sub(/\.rb$/, '')

                if zero == 'puppet'
                    case argv.first
                    when nil;              [ stdin.tty? ? nil : "apply", argv] # ttys get usage info
                    when "--help";         [nil,     argv] # help should give you usage, not the help for `puppet apply`
                    when /^-|\.pp$|\.rb$/; ["apply", argv]
                    else [ argv.first, argv[1..-1] ]
                    end
                else
                    [ zero, argv ]
                end
            end
        end
    end
end
