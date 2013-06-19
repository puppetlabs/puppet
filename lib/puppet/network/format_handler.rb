require 'yaml'
require 'puppet/network'
require 'puppet/network/format'

module Puppet::Network::FormatHandler
  class FormatError < Puppet::Error; end

  @formats = {}

  def self.create(*args, &block)
    instance = Puppet::Network::Format.new(*args, &block)

    @formats[instance.name] = instance
    instance
  end

  def self.create_serialized_formats(name,options = {},&block)
    ["application/x-#{name}", "application/#{name}", "text/x-#{name}", "text/#{name}"].each { |mime_type|
      create name, {:mime => mime_type}.update(options), &block
    }
  end

  def self.format(name)
    @formats[name.to_s.downcase.intern]
  end

  def self.format_for(name)
    name = format_to_canonical_name(name)
    format(name)
  end

  def self.format_by_extension(ext)
    @formats.each do |name, format|
      return format if format.extension == ext
    end
    nil
  end

  # Provide a list of all formats.
  def self.formats
    @formats.keys
  end

  # Return a format capable of handling the provided mime type.
  def self.mime(mimetype)
    mimetype = mimetype.to_s.downcase
    @formats.values.find { |format| format.mime == mimetype }
  end

  # Return a format name given:
  #  * a format name
  #  * a mime-type
  #  * a format instance
  def self.format_to_canonical_name(format)
    case format
    when Puppet::Network::Format
      out = format
    when %r{\w+/\w+}
      out = mime(format)
    else
      out = format(format)
    end
    raise ArgumentError, "No format match the given format name or mime-type (#{format})" if out.nil?
    out.name
  end
end

require 'puppet/network/formats'
