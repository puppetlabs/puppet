require 'puppet/network/format_handler'

Puppet::Network::FormatHandler.create_serialized_formats(:msgpack, :weight => 20, :mime => "application/x-msgpack", :required_methods => [:render_method, :intern_method], :intern_method => :from_data_hash) do

  confine :feature => :msgpack

  def intern(klass, text)
    data = MessagePack.unpack(text)
    return data if data.is_a?(klass)
    klass.from_data_hash(data)
  end

  def intern_multiple(klass, text)
    MessagePack.unpack(text).collect do |data|
      klass.from_data_hash(data)
    end
  end

  def render_multiple(instances)
    instances.to_msgpack
  end
end

Puppet::Network::FormatHandler.create_serialized_formats(:yaml) do
  def intern(klass, text)
    data = YAML.load(text, :safe => true, :deserialize_symbols => true)
    data_to_instance(klass, data)
  end

  def intern_multiple(klass, text)
    data = YAML.load(text, :safe => true, :deserialize_symbols => true)
    unless data.respond_to?(:collect)
      raise Puppet::Network::FormatHandler::FormatError, "Serialized YAML did not contain a collection of instances when calling intern_multiple"
    end

    data.collect do |datum|
      data_to_instance(klass, datum)
    end
  end

  def data_to_instance(klass, data)
    return data if data.is_a?(klass)

    unless data.is_a? Hash
      raise Puppet::Network::FormatHandler::FormatError, "Serialized YAML did not contain a valid instance of #{klass}"
    end

    klass.from_data_hash(data)
  end

  def render(instance)
    instance.to_yaml
  end

  # Yaml monkey-patches Array, so this works.
  def render_multiple(instances)
    instances.to_yaml
  end

  def supported?(klass)
    true
  end
end

# This is a "special" format which is used for the moment only when sending facts
# as REST GET parameters (see Puppet::Configurer::FactHandler).
# This format combines a yaml serialization, then zlib compression and base64 encoding.
Puppet::Network::FormatHandler.create_serialized_formats(:b64_zlib_yaml) do
  require 'base64'

  def use_zlib?
    Puppet.features.zlib? && Puppet[:zlib]
  end

  def requiring_zlib
    if use_zlib?
      yield
    else
      raise Puppet::Error, "the zlib library is not installed or is disabled."
    end
  end

  def intern(klass, text)
    requiring_zlib do
      Puppet::Network::FormatHandler.format(:yaml).intern(klass, decode(text))
    end
  end

  def intern_multiple(klass, text)
    requiring_zlib do
      Puppet::Network::FormatHandler.format(:yaml).intern_multiple(klass, decode(text))
    end
  end

  def render(instance)
    encode(instance.to_yaml)
  end

  def render_multiple(instances)
    encode(instances.to_yaml)
  end

  def supported?(klass)
    true
  end

  def decode(data)
    Zlib::Inflate.inflate(Base64.decode64(data))
  end

  def encode(text)
    requiring_zlib do
      Base64.encode64(Zlib::Deflate.deflate(text, Zlib::BEST_COMPRESSION))
    end
  end
end

Puppet::Network::FormatHandler.create(:s, :mime => "text/plain", :extension => "txt")

# A very low-weight format so it'll never get chosen automatically.
Puppet::Network::FormatHandler.create(:raw, :mime => "application/x-raw", :weight => 1) do
  def intern_multiple(klass, text)
    raise NotImplementedError
  end

  def render_multiple(instances)
    raise NotImplementedError
  end

  # LAK:NOTE The format system isn't currently flexible enough to handle
  # what I need to support raw formats just for individual instances (rather
  # than both individual and collections), but we don't yet have enough data
  # to make a "correct" design.
  #   So, we hack it so it works for singular but fail if someone tries it
  # on plurals.
  def supported?(klass)
    true
  end
end

Puppet::Network::FormatHandler.create_serialized_formats(:pson, :weight => 10, :required_methods => [:render_method, :intern_method], :intern_method => :from_data_hash) do
  def intern(klass, text)
    data_to_instance(klass, PSON.parse(text))
  end

  def intern_multiple(klass, text)
    PSON.parse(text).collect do |data|
      data_to_instance(klass, data)
    end
  end

  # PSON monkey-patches Array, so this works.
  def render_multiple(instances)
    instances.to_pson
  end

  # If they pass class information, we want to ignore it.  By default,
  # we'll include class information but we won't rely on it - we don't
  # want class names to be required because we then can't change our
  # internal class names, which is bad.
  def data_to_instance(klass, data)
    if data.is_a?(Hash) and d = data['data']
      data = d
    end
    return data if data.is_a?(klass)
    klass.from_data_hash(data)
  end
end

# This is really only ever going to be used for Catalogs.
Puppet::Network::FormatHandler.create_serialized_formats(:dot, :required_methods => [:render_method])


Puppet::Network::FormatHandler.create(:console,
                                      :mime   => 'text/x-console-text',
                                      :weight => 0) do
  def json
    @json ||= Puppet::Network::FormatHandler.format(:pson)
  end

  def render(datum)
    # String to String
    return datum if datum.is_a? String
    return datum if datum.is_a? Numeric

    # Simple hash to table
    if datum.is_a? Hash and datum.keys.all? { |x| x.is_a? String or x.is_a? Numeric }
      output = ''
      column_a = datum.empty? ? 2 : datum.map{ |k,v| k.to_s.length }.max + 2
      datum.sort_by { |k,v| k.to_s } .each do |key, value|
        output << key.to_s.ljust(column_a)
        output << json.render(value).
          chomp.gsub(/\n */) { |x| x + (' ' * column_a) }
        output << "\n"
      end
      return output
    end

    # Print one item per line for arrays
    if datum.is_a? Array
      output = ''
      datum.each do |item|
        output << item.to_s
        output << "\n"
      end
      return output
    end

    # ...or pretty-print the inspect outcome.
    return json.render(datum)
  end

  def render_multiple(data)
    data.collect(&:render).join("\n")
  end
end
