require 'yaml'

module Puppet::Util::Yaml
  YamlLoadExceptions = [::StandardError, ::Psych::Exception]

  class YamlLoadError < Puppet::Error; end

  # Safely load the content as YAML. By default only the following
  # classes can be deserialized:
  #
  # * TrueClass
  # * FalseClass
  # * NilClass
  # * Numeric
  # * String
  # * Array
  # * Hash
  #
  # Attempting to deserialize other classes will raise an YamlLoadError
  # exception unless they are specified in the array of *allowed_classes*.
  # @param [String] yaml The yaml content to parse.
  # @param [Array] allowed_classes Additional list of classes that can be deserialized.
  # @param [String] filename The filename to load from, used if an exception is raised.
  # @raise [YamlLoadException] If deserialization fails.
  # @return The parsed YAML, which can be Hash, Array or scalar types.
  def self.safe_load(yaml, allowed_classes = [], filename = nil)
    data = YAML.safe_load(yaml, allowed_classes, [], true, filename)
    data = false if data.nil?
    data
  rescue ::Psych::DisallowedClass => detail
    path = filename ? "(#{filename})" : "(<unknown>)"
    raise YamlLoadError.new("#{path}: #{detail.message}", detail)
  rescue *YamlLoadExceptions => detail
    raise YamlLoadError.new(detail.message, detail)
  end

  # Safely load the content from a file as YAML.
  #
  # @see Puppet::Util::Yaml.safe_load
  def self.safe_load_file(filename, allowed_classes = [])
    yaml = Puppet::FileSystem.read(filename, :encoding => 'bom|utf-8')
    safe_load(yaml, allowed_classes, filename)
  end

  # @deprecated Use {#safe_load_file} instead.
  def self.load_file(filename, default_value = false, strip_classes = false)
    Puppet.deprecation_warning(_("Puppet::Util::Yaml.load_file is deprecated. Use safe_load_file instead."))

    if(strip_classes) then
      data = YAML::parse_file(filename)
      data.root.each do |o|
        if o.respond_to?(:tag=) and
           o.tag != nil and
           o.tag.start_with?("!ruby")
          o.tag = nil
        end
      end
      data.to_ruby || default_value
    else
      yaml = YAML.load_file(filename)
      yaml || default_value
    end
  rescue *YamlLoadExceptions => detail
    raise YamlLoadError.new(detail.message, detail)
  end

  def self.dump(structure, filename)
    Puppet::Util.replace_file(filename, 0660) do |fh|
      YAML.dump(structure, fh)
    end
  end
end
