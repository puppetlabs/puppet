module Puppet
    module Util
        class CommandLine
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

            def initialize( zero = $0, argv = ARGV, stdin = STDIN )
                @zero  = zero
                @argv  = argv.dup
                @stdin = stdin

                @subcommand_name, @args = subcommand_and_args( @zero, @argv, @stdin )
            end

            attr :subcommand_name
            attr :args

            def appdir
                File.join('puppet', 'application')
            end

            def available_subcommands
                absolute_appdir = $:.collect { |x| File.join(x,'puppet','application') }.detect{ |x| File.directory?(x) }
                Dir[File.join(absolute_appdir, '*.rb')].map{|fn| File.basename(fn, '.rb')}
            end

            def usage_message
                usage = "Usage: puppet command <space separated arguments>"
                available = "Available commands are: #{available_subcommands.sort.join(', ')}"
                [usage, available].join("\n")
            end

            def require_application(application)
                require File.join(appdir, application)
            end

            def execute
                if subcommand_name.nil?
                    puts usage_message
                elsif available_subcommands.include?(subcommand_name) #subcommand
                    require_application subcommand_name
                    Puppet::Application.find(subcommand_name).new(self).run
                else
                    abort "Error: Unknown command #{subcommand_name}.\n#{usage_message}"
                end
            end

            def legacy_executable_name
                LegacyName[ subcommand_name ]
            end

            private

            def subcommand_and_args( zero, argv, stdin )
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
