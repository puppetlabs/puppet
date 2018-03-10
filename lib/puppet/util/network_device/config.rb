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
      File.open(@file) do |f|
        file_line_count = 1
        f.each do |line|
          case line
          when /^\s*#/ # skip comments
            file_line_count += 1
            next
          when /^\s*$/  # skip blank lines
            file_line_count += 1
            next
          when /^\[([\w.-]+)\]\s*$/ # [device.fqdn]
            name = $1
            name.chomp!
            if devices.include?(name)
              file_error_location = Puppet::Util::Errors.error_location(nil, file_line_count)
              device_error_location = Puppet::Util::Errors.error_location(nil, device.line)
              raise Puppet::Error, _("Duplicate device found at %{file_error_location}, already found at %{device_error_location}") %
                  { file_error_location: file_error_location, device_error_location: device_error_location }
            end
            device = OpenStruct.new
            device.name = name
            device.line = file_line_count
            device.options = { :debug => false }
            Puppet.debug "found device: #{device.name} at #{device.line}"
            devices[name] = device
          when /^\s*(type|url|debug)(\s+(.+)\s*)*$/
            parse_directive(device, $1, $3, file_line_count)
          else
            error_location_str = Puppet::Util::Errors.error_location(nil, file_line_count)
            raise Puppet::Error, _("Invalid entry at %{error_location}: %{file_text}") %
                { error_location: error_location_str, file_text: line }
          end
        end
      end
    rescue Errno::EACCES
      Puppet.err _("Configuration error: Cannot read %{file}; cannot serve") % { file: @file }
      #raise Puppet::Error, "Cannot read #{@config}"
    rescue Errno::ENOENT
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
      error_location_str = Puppet::Util::Errors.error_location(nil, count)
      raise Puppet::Error, _("Invalid argument '%{var}' at %{error_location}") % { var: var, error_location: error_location_str }
    end
  end

end
