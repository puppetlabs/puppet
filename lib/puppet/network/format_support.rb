require 'puppet/network/format_handler'

# Provides network serialization support when included
# @api public
module Puppet::Network::FormatSupport
  def self.included(klass)
    klass.extend(ClassMethods)
  end

  module ClassMethods
    def convert_from(format, data)
      get_format(format).intern(self, data)
    rescue => err
      #TRANSLATORS "intern" is a function name and should not be translated
      raise Puppet::Network::FormatHandler::FormatError, _("Could not intern from %{format}: %{err}") % { format: format, err: err }, err.backtrace
    end

    def convert_from_multiple(format, data)
      get_format(format).intern_multiple(self, data)
    rescue => err
      #TRANSLATORS "intern_multiple" is a function name and should not be translated
      raise Puppet::Network::FormatHandler::FormatError, _("Could not intern_multiple from %{format}: %{err}") % { format: format, err: err }, err.backtrace
    end

    def render_multiple(format, instances)
      get_format(format).render_multiple(instances)
    rescue => err
      #TRANSLATORS "render_multiple" is a function name and should not be translated
      raise Puppet::Network::FormatHandler::FormatError, _("Could not render_multiple to %{format}: %{err}") % { format: format, err: err }, err.backtrace
    end

    def default_format
      supported_formats[0]
    end

    def support_format?(name)
      Puppet::Network::FormatHandler.format(name).supported?(self)
    end

    def supported_formats
      result = format_handler.formats.collect do |f|
        format_handler.format(f)
      end.find_all do |f|
        f.supported?(self)
      end.sort do |a, b|
        # It's an inverse sort -- higher weight formats go first.
        b.weight <=> a.weight
      end.collect do |f|
        f.name
      end

      result = put_preferred_format_first(result)

      Puppet.debug "#{friendly_name} supports formats: #{result.join(' ')}"

      result
    end

    # @api private
    def get_format(format_name)
      format_handler.format_for(format_name)
    end

    private

    def format_handler
      Puppet::Network::FormatHandler
    end

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

  def to_msgpack(*args)
    to_data_hash.to_msgpack(*args)
  end

  # @deprecated, use to_json
  def to_pson(*args)
    to_data_hash.to_pson(*args)
  end

  def to_json(*args)
    Puppet::Util::Json.dump(to_data_hash, *args)
  end

  def render(format = nil)
    format ||= self.class.default_format

    self.class.get_format(format).render(self)
  rescue => err
    #TRANSLATORS "render" is a function name and should not be translated
    raise Puppet::Network::FormatHandler::FormatError, _("Could not render to %{format}: %{err}") % { format: format, err: err }, err.backtrace
  end

  def mime(format = nil)
    format ||= self.class.default_format

    self.class.get_format(format).mime
  rescue => err
    #TRANSLATORS "mime" is a function name and should not be translated
    raise Puppet::Network::FormatHandler::FormatError, _("Could not mime to %{format}: %{err}") % { format: format, err: err }, err.backtrace
  end

  def support_format?(name)
    self.class.support_format?(name)
  end

  # @comment Document to_data_hash here as it is called as a hook from to_msgpack if it exists
  # @!method to_data_hash(*args)
  # @api public
  # @abstract
  # This method may be implemented to return a hash object that is used for serializing.
  # The object returned by this method should contain all the info needed to instantiate it again.
  # If the method exists it will be called from to_msgpack and other serialization methods.
  # @return [Hash]
end

