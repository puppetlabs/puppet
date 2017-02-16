# @since 5.0.0
#
Puppet::Functions.create_function(:eyaml_lookup_key) do
  unless Puppet.features.hiera_eyaml?
    raise Puppet::DataBinding::LookupError, 'Lookup using eyaml lookup_key function is only supported when the hiera_eyaml library is present'
  end

  require 'hiera/backend/eyaml/encryptor'
  require 'hiera/backend/eyaml/utils'
  require 'hiera/backend/eyaml/options'
  require 'hiera/backend/eyaml/parser/parser'

  dispatch :eyaml_lookup_key do
    param 'String[1]', :key
    param 'Hash[String[1],Any]', :options
    param 'Puppet::LookupContext', :context
  end

  def eyaml_lookup_key(key, options, context)
    return context.cached_value(key) if context.cache_has_key(key)

    # nil key is used to indicate that the cache contains the raw content of the eyaml file
    raw_data = context.cached_value(nil)
    if raw_data.nil?
      options.each_pair do |k, v|
        unless k == 'path'
          Hiera::Backend::Eyaml::Options[k.to_sym] = v
          context.explain { "Setting Eyaml option '#{k}' to '#{v}'" }
        end
      end
      raw_data = load_data_hash(options)
      context.cache(nil, raw_data)
    end
    context.not_found unless raw_data.include?(key)
    context.cache(key, decrypt_value(raw_data[key], context))
  end

  def load_data_hash(options)
    begin
      data = YAML.load_file(options['path'])
      Puppet::Pops::Lookup::HieraConfig.symkeys_to_string(data.is_a?(Hash) ? data : {})
    rescue YAML::SyntaxError => ex
      # Psych errors includes the absolute path to the file, so no need to add that
      # to the message
      raise Puppet::DataBinding::LookupError, "Unable to parse #{ex.message}"
    end
  end

  def decrypt_value(value, context)
    case value
    when String
      decrypt(value, context)
    when Hash
      result = {}
      value.each_pair { |k, v| result[k] = decrypt_value(v, context) }
      result
    when Array
      value.map { |v| decrypt_value(v, context) }
    else
      value
    end
  end

  def decrypt(data, context)
    return context.interpolate(data) unless encrypted?(data)
    tokens = Hiera::Backend::Eyaml::Parser::ParserFactory.hiera_backend_parser.parse(data)
    tokens.map(&:to_plain_text).join.chomp
  end

  def encrypted?(data)
    /.*ENC\[.*?\]/ =~ data ? true : false
  end
end
