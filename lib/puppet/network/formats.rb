require 'puppet/network/format_handler'
require 'puppet/util/json'

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
    data = YAML.load(text)
    data_to_instance(klass, data)
  end

  def intern_multiple(klass, text)
    data = YAML.load(text)
    unless data.respond_to?(:collect)
      raise Puppet::Network::FormatHandler::FormatError, _("Serialized YAML did not contain a collection of instances when calling intern_multiple")
    end

    data.collect do |datum|
      data_to_instance(klass, datum)
    end
  end

  def data_to_instance(klass, data)
    return data if data.is_a?(klass)

    unless data.is_a? Hash
      raise Puppet::Network::FormatHandler::FormatError, _("Serialized YAML did not contain a valid instance of %{klass}") % { klass: klass }
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

Puppet::Network::FormatHandler.create(:s, :mime => "text/plain", :charset => Encoding::UTF_8, :extension => "txt")

# By default, to_binary is called to render and from_binary called to intern. Note unlike
# text-based formats (json, yaml, etc), we don't use to_data_hash for binary.
Puppet::Network::FormatHandler.create(:binary, :mime => "application/octet-stream", :weight => 1,
                                      :required_methods => [:render_method, :intern_method]) do
end

# PSON is deprecated
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

  # If they pass class information, we want to ignore it.
  # This is required for compatibility with Puppet 3.x
  def data_to_instance(klass, data)
    if data.is_a?(Hash) and d = data['data']
      data = d
    end
    return data if data.is_a?(klass)
    klass.from_data_hash(data)
  end
end

Puppet::Network::FormatHandler.create_serialized_formats(:json, :mime => 'application/json', :charset => Encoding::UTF_8, :weight => 15, :required_methods => [:render_method, :intern_method], :intern_method => :from_data_hash) do
  def intern(klass, text)
    data_to_instance(klass, Puppet::Util::Json.load(text))
  end

  def intern_multiple(klass, text)
    Puppet::Util::Json.load(text).collect do |data|
      data_to_instance(klass, data)
    end
  end

  def render_multiple(instances)
    Puppet::Util::Json.dump(instances)
  end

  # Unlike PSON, we do not need to unwrap the data envelope, because legacy 3.x agents
  # have never supported JSON
  def data_to_instance(klass, data)
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
    @json ||= Puppet::Network::FormatHandler.format(:json)
  end

  def render(datum)
    return datum if datum.is_a?(String) || datum.is_a?(Numeric)

    # Simple hash to table
    if datum.is_a?(Hash) && datum.keys.all? { |x| x.is_a?(String) || x.is_a?(Numeric) }
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
    Puppet::Util::Json.dump(datum, :pretty => true, :quirks_mode => true)
  end

  def render_multiple(data)
    data.collect(&:render).join("\n")
  end
end
