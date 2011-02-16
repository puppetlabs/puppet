require 'puppet/application'

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
    return send(command) if %w{get backup restore}.include? command
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
        $stderr.puts "#{file}: no such file"
        next
      end
      unless FileTest.readable?(file)
        $stderr.puts "#{file}: cannot read file"
        next
      end
      md5 = @client.backup(file)
      puts "#{file}: #{md5}"
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

    Signal.trap(:INT) do
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

      exit(Puppet.settings.print_configs ? 0 : 1) if Puppet.settings.print_configs?

    require 'puppet/file_bucket/dipper'
    begin
      if options[:local] or options[:bucket]
        path = options[:bucket] || Puppet[:bucketdir]
        @client = Puppet::FileBucket::Dipper.new(:Path => path)
      else
        @client = Puppet::FileBucket::Dipper.new(:Server => Puppet[:server])
      end
    rescue => detail
      $stderr.puts detail
      puts detail.backtrace if Puppet[:trace]
      exit(1)
    end
  end

end

