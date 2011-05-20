require 'ostruct'
require 'puppet/util/loadedfile'

class Puppet::Util::NetworkDevice::Config < Puppet::Util::LoadedFile

  def self.main
    @main ||= self.new
  end

  def self.devices
    main.devices || []
  end

  attr_reader :devices

  def exists?
    FileTest.exists?(@file)
  end

  def initialize()
    @file = Puppet[:deviceconfig]

    raise Puppet::DevError, "No device config file defined" unless @file
    return unless self.exists?
    super(@file)
    @devices = {}

    read(true) # force reading at start
  end

  # Read the configuration file.
  def read(force = false)
    return unless FileTest.exists?(@file)

    parse if force or changed?
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
          when /^\[([\w.]+)\]\s*$/ # [device.fqdn]
            name = $1
            name.chomp!
            raise ConfigurationError, "Duplicate device found at line #{count}, already found at #{device.line}" if devices.include?(name)
            device = OpenStruct.new
            device.name = name
            device.line = count
            Puppet.debug "found device: #{device.name} at #{device.line}"
            devices[name] = device
          when /^\s*(type|url)\s+(.+)$/
            parse_directive(device, $1, $2, count)
          else
            raise ConfigurationError, "Invalid line #{count}: #{line}"
          end
          count += 1
        }
      }
    rescue Errno::EACCES => detail
      Puppet.err "Configuration error: Cannot read #{@file}; cannot serve"
      #raise Puppet::Error, "Cannot read #{@config}"
    rescue Errno::ENOENT => detail
      Puppet.err "Configuration error: '#{@file}' does not exit; cannot serve"
    end

    @devices = devices
  end

  def parse_directive(device, var, value, count)
    case var
    when "type"
      device.provider = value
    when "url"
      device.url = value
    else
      raise ConfigurationError,
        "Invalid argument '#{var}' at line #{count}"
    end
  end

end