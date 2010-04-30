require 'puppet'
require 'puppet/application'
require 'puppet/file_bucket/dipper'

class Puppet::Application::Filebucket < Puppet::Application

    should_not_parse_config

    option("--bucket BUCKET","-b")
    option("--debug","-d")
    option("--local","-l")
    option("--remote","-r")
    option("--verbose","-v")

    attr :args

    def run_command
        @args = command_line.args
        command = args.shift
        return send(command) if %w[get backup restore].include? command
        help
    end

    def get
        md5 = args.shift
        out = @client.getfile(md5)
        print out
    end

    def backup
        args.each do |file|
            unless FileTest.exists?(file)
                $stderr.puts "%s: no such file" % file
                next
            end
            unless FileTest.readable?(file)
                $stderr.puts "%s: cannot read file" % file
                next
            end
            md5 = @client.backup(file)
            puts "%s: %s" % [file, md5]
        end
    end

    def restore
        file = args.shift
        md5 = args.shift
        @client.restore(file, md5)
    end

    def setup
        Puppet::Log.newdestination(:console)

        @client = nil
        @server = nil

        trap(:INT) do
            $stderr.puts "Cancelling"
            exit(1)
        end

        if options[:debug]
            Puppet::Log.level = :debug
        elsif options[:verbose]
            Puppet::Log.level = :info
        end

        # Now parse the config
        Puppet.parse_config

        if Puppet.settings.print_configs?
                exit(Puppet.settings.print_configs ? 0 : 1)
        end

        begin
            if options[:local] or options[:bucket]
                path = options[:bucket] || Puppet[:bucketdir]
                @client = Puppet::FileBucket::Dipper.new(:Path => path)
            else
                @client = Puppet::FileBucket::Dipper.new(:Server => Puppet[:server])
            end
        rescue => detail
            $stderr.puts detail
            if Puppet[:trace]
                puts detail.backtrace
            end
            exit(1)
        end
    end

end

