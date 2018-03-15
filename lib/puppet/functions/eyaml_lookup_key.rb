# The `eyaml_lookup_key` is a hiera 5 `lookup_key` data provider function.
# See [the configuration guide documentation](https://docs.puppet.com/puppet/latest/hiera_config_yaml_5.html#configuring-a-hierarchy-level-hiera-eyaml) for
# how to use this function.
#
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

    # Can't do this with an argument_mismatch dispatcher since there is no way to declare a struct that at least
    # contains some keys but may contain other arbitrary keys.
    unless options.include?('path')
      #TRANSLATORS 'eyaml_lookup_key':, 'path', 'paths' 'glob', 'globs', 'mapped_paths', and lookup_key should not be translated
      raise ArgumentError,
        _("'eyaml_lookup_key': one of 'path', 'paths' 'glob', 'globs' or 'mapped_paths' must be declared in hiera.yaml"\
              " when using this lookup_key function")
    end

    # nil key is used to indicate that the cache contains the raw content of the eyaml file
    raw_data = context.cached_value(nil)
    if raw_data.nil?
      raw_data = load_data_hash(options, context)
      context.cache(nil, raw_data)
    end
    context.not_found unless raw_data.include?(key)
    context.cache(key, decrypt_value(raw_data[key], context, options))
  end

  def load_data_hash(options, context)
    path = options['path']
    context.cached_file_data(path) do |content|
      begin
        data = YAML.load(content, path)
        if data.is_a?(Hash)
          Puppet::Pops::Lookup::HieraConfig.symkeys_to_string(data)
        else
          msg = _("%{path}: file does not contain a valid yaml hash") % { path: path }
          raise Puppet::DataBinding::LookupError, msg if Puppet[:strict] == :error && data != false
          Puppet.warning(msg)
          {}
        end
      rescue YAML::SyntaxError => ex
        # Psych errors includes the absolute path to the file, so no need to add that
        # to the message
        raise Puppet::DataBinding::LookupError, "Unable to parse #{ex.message}"
      end
    end
  end

  def decrypt_value(value, context, options)
    case value
    when String
      decrypt(value, context, options)
    when Hash
      result = {}
      value.each_pair { |k, v| result[context.interpolate(k)] = decrypt_value(v, context, options) }
      result
    when Array
      value.map { |v| decrypt_value(v, context, options) }
    else
      value
    end
  end

  def decrypt(data, context, options)
    if encrypted?(data)
      # Options must be set prior to each call to #parse since they end up as static variables in
      # the Options class. They cannot be set once before #decrypt_value is called, since each #decrypt
      # might cause a new lookup through interpolation. That lookup in turn, might use a different eyaml
      # config.
      #
      Hiera::Backend::Eyaml::Options.set(options)
      tokens = Hiera::Backend::Eyaml::Parser::ParserFactory.hiera_backend_parser.parse(data)
      data = tokens.map(&:to_plain_text).join.chomp
    end
    context.interpolate(data)
  end

  def encrypted?(data)
    /.*ENC\[.*?\]/ =~ data ? true : false
  end
end
