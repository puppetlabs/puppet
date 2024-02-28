# frozen_string_literal: true

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
    if Gem::Version.new(Psych::VERSION) >= Gem::Version.new('3.1.0')
      data = YAML.safe_load(yaml, permitted_classes: allowed_classes, aliases: true, filename: filename)
    else
      data = YAML.safe_load(yaml, allowed_classes, [], true, filename)
    end
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

  # Safely load the content from a file as YAML if
  # contents are in valid format. This method does not
  # raise error but returns `nil` when invalid file is
  # given.
  def self.safe_load_file_if_valid(filename, allowed_classes = [])
    safe_load_file(filename, allowed_classes)
  rescue YamlLoadError, ArgumentError, Errno::ENOENT => detail
    Puppet.debug("Could not retrieve YAML content from '#{filename}': #{detail.message}")
    nil
  end

  def self.dump(structure, filename)
    Puppet::FileSystem.replace_file(filename, 0o660) do |fh|
      YAML.dump(structure, fh)
    end
  end
end
