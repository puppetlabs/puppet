require 'yaml'

module Puppet::Util::Yaml
  if defined?(::Psych::SyntaxError)
    YamlLoadExceptions = [::StandardError, ::Psych::Exception]
  else
    YamlLoadExceptions = [::StandardError]
  end

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
  # @param String yaml The yaml content to parse
  # @param Array allowed_classes Additional list of classes that can be
  # deserialized
  # @param String filename The filename to load from, used if an exception
  # is raised.
  # @returns The parsed YAML, typically a Hash
  def self.safe_load(yaml, allowed_classes = [], filename = nil)
    data = YAML.safe_load(yaml, allowed_classes, [], false, filename)
    data = false if data.nil?
    data
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

  def self.load_file(filename, default_value = false, strip_classes = false)
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
