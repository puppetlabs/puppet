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

  def self.extended(klass)
    klass.extend(ClassMethods)

    klass.send(:include, InstanceMethods)
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

  module ClassMethods
    def format_handler
      Puppet::Network::FormatHandler
    end

    def convert_from(format, data)
      format_handler.format_for(format).intern(self, data)
    rescue => err
      raise FormatError, "Could not intern from #{format}: #{err}", err.backtrace
    end

    def convert_from_multiple(format, data)
      format_handler.format_for(format).intern_multiple(self, data)
    rescue => err
      raise FormatError, "Could not intern_multiple from #{format}: #{err}", err.backtrace
    end

    def render_multiple(format, instances)
      format_handler.format_for(format).render_multiple(instances)
    rescue => err
      raise FormatError, "Could not render_multiple to #{format}: #{err}", err.backtrace
    end

    def default_format
      supported_formats[0]
    end

    def support_format?(name)
      Puppet::Network::FormatHandler.format(name).supported?(self)
    end

    def supported_formats
      result = format_handler.formats.collect { |f| format_handler.format(f) }.find_all { |f| f.supported?(self) }.collect { |f| f.name }.sort do |a, b|
        # It's an inverse sort -- higher weight formats go first.
        format_handler.format(b).weight <=> format_handler.format(a).weight
      end

      result = put_preferred_format_first(result)

      Puppet.debug "#{friendly_name} supports formats: #{result.map{ |f| f.to_s }.sort.join(' ')}; using #{result.first}"

      result
    end

    private

    def friendly_name
      if self.respond_to? :indirection
        indirection.name
      else
        self
      end
    end

    def put_preferred_format_first(list)
      preferred_format = Puppet.settings[:preferred_serialization_format].to_sym
      if list.include?(preferred_format)
        list.delete(preferred_format)
        list.unshift(preferred_format)
      else
        Puppet.debug "Value of 'preferred_serialization_format' (#{preferred_format}) is invalid for #{friendly_name}, using default (#{list.first})"
      end
      list
    end
  end

  module InstanceMethods
    def render(format = nil)
      format ||= self.class.default_format

      Puppet::Network::FormatHandler.format_for(format).render(self)
    rescue => err
      raise FormatError, "Could not render to #{format}: #{err}", err.backtrace
    end

    def mime(format = nil)
      format ||= self.class.default_format

      Puppet::Network::FormatHandler.format_for(format).mime
    rescue => err
      raise FormatError, "Could not mime to #{format}: #{err}", err.backtrace
    end

    def support_format?(name)
      self.class.support_format?(name)
    end
  end
end

require 'puppet/network/formats'
