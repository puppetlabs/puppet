require 'ostruct'
require 'puppet/util/watched_file'
require 'puppet/util/network_device'

class Puppet::Util::NetworkDevice::Config

  def self.main
    @main ||= self.new
  end

  def self.devices
    main.devices || []
  end

  attr_reader :devices

  def exists?
    Puppet::FileSystem.exist?(@file.to_str)
  end

  def initialize
    @file = Puppet::Util::WatchedFile.new(Puppet[:deviceconfig])

    @devices = {}

    read(true) # force reading at start
  end

  # Read the configuration file.
  def read(force = false)
    return unless exists?

    parse if force or @file.changed?
  end

  private

  def parse
    begin
      devices = {}
      device = nil
      File.open(@file) { |f|
        count = 1
        f.each { |line|
          case line
          when /^\s*#/ # skip comments
            count += 1
            next
          when /^\s*$/  # skip blank lines
            count += 1
            next
          when /^\[([\w.-]+)\]\s*$/ # [device.fqdn]
            name = $1
            name.chomp!
            raise Puppet::Error, _("Duplicate device found at line %{count}, already found at %{line}") % { count: count, line: device.line } if devices.include?(name)
            device = OpenStruct.new
            device.name = name
            device.line = count
            device.options = { :debug => false }
            Puppet.debug "found device: #{device.name} at #{device.line}"
            devices[name] = device
          when /^\s*(type|url|debug)(\s+(.+)\s*)*$/
            parse_directive(device, $1, $3, count)
          else
            raise Puppet::Error, _("Invalid line %{count}: %{line}") % { count: count, line: line }
          end
          count += 1
        }
      }
    rescue Errno::EACCES => detail
      Puppet.err _("Configuration error: Cannot read %{file}; cannot serve") % { file: @file }
      #raise Puppet::Error, "Cannot read #{@config}"
    rescue Errno::ENOENT => detail
      Puppet.err _("Configuration error: '%{file}' does not exit; cannot serve") % { file: @file }
    end

    @devices = devices
  end

  def parse_directive(device, var, value, count)
    case var
    when "type"
      device.provider = value
    when "url"
      begin
        URI.parse(value)
      rescue URI::InvalidURIError
        raise Puppet::Error, _("%{value} is an invalid url") % { value: value }
      end
      device.url = value
    when "debug"
      device.options[:debug] = true
    else
      raise Puppet::Error, _("Invalid argument '%{var}' at line %{count}") % { var: var, count: count }
    end
  end

end
