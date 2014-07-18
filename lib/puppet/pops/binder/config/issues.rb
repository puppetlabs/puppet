module Puppet::Pops::Binder::Config::Issues
  # (see Puppet::Pops::Issues#issue)
  def self.issue (issue_code, *args, &block)
    Puppet::Pops::Issues.issue(issue_code, *args, &block)
  end

  CONFIG_FILE_NOT_FOUND = issue :CONFIG_FILE_NOT_FOUND do
    "The binder configuration file: #{semantic} can not be found."
  end

  CONFIG_FILE_SYNTAX_ERROR = issue :CONFIG_FILE_SYNTAX_ERROR, :detail do
    "Syntax error in configuration file: #{detail}"
  end

  CONFIG_IS_NOT_HASH = issue :CONFIG_IS_NOT_HASH do
    "The configuration file '#{semantic}' has no hash at the top level"
  end

  CONFIG_LAYERS_MISSING = issue :CONFIG_LAYERS_MISSING do
    "The configuration file '#{semantic}' has no 'layers' entry in the top level hash"
  end

  CONFIG_CATEGORIES_MISSING = issue :CONFIG_CATEGORIES_MISSING do
    "The configuration file '#{semantic}' has no 'categories' entry in the top level hash"
  end

  CONFIG_VERSION_MISSING = issue :CONFIG_VERSION_MISSING do
    "The configuration file '#{semantic}' has no 'version' entry in the top level hash"
  end

  LAYERS_IS_NOT_ARRAY = issue :LAYERS_IS_NOT_ARRAY, :klass do
    "The configuration file '#{semantic}' should contain a 'layers' key with an Array value, got: #{klass.name}"
  end

  LAYER_IS_NOT_HASH = issue :LAYER_IS_NOT_HASH, :klass do
    "The configuration file '#{semantic}' should contain one hash per layer, got #{klass.name} instead of Hash"
  end

  DUPLICATE_LAYER_NAME = issue :DUPLICATE_LAYER_NAME, :name do
    "Duplicate layer '#{name}' in configuration file #{semantic}"
  end

  UNKNOWN_LAYER_ATTRIBUTE = issue :UNKNOWN_LAYER_ATTRIBUTE, :name do
    "Unknown layer attribute '#{name}' in configuration file #{semantic}"
  end

  BINDINGS_REF_NOT_STRING_OR_ARRAY = issue :BINDINGS_REF_NOT_STRING_OR_ARRAY, :kind do
    "Configuration file #{semantic} has bindings reference in '#{kind}' that is neither a String nor an Array."
  end

  MISSING_SCHEME = issue :MISSING_SCHEME, :uri do
    "Configuration file #{semantic} contains a bindings reference: '#{uri}' without scheme."
  end

  UNKNOWN_REF_SCHEME = issue :UNKNOWN_REF_SCHEME, :uri, :kind do
    "Configuration file #{semantic} contains a bindings reference: '#{kind}' => '#{uri}' with unknown scheme"
  end

  REF_WITHOUT_PATH = issue :REF_WITHOUT_PATH, :uri, :kind do
    "Configuration file #{semantic} contains a bindings reference: '#{kind}' => '#{uri}' without path"
  end

  BINDINGS_REF_INVALID_URI = issue :BINDINGS_REF_INVALID_URI, :msg do
    "Configuration file #{semantic} contains a bindings reference: '#{kind}' => invalid uri, msg: '#{msg}'"
  end

  LAYER_ATTRIBUTE_IS_SYMBOL = issue :LAYER_ATTRIBUTE_IS_SYMBOL, :name do
    "Configuration file #{semantic} contains a layer attribute '#{name}' that is a Symbol (should be String)"
  end

  LAYER_NAME_NOT_STRING = issue :LAYER_NAME_NOT_STRING, :class_name do
    "Configuration file #{semantic} contains a layer name that is not a String, got a: '#{class_name}'"
  end

  CONFIG_WRONG_VERSION = issue :CONFIG_WRONG_VERSION, :expected, :actual do
    "The configuration file '#{semantic}' has unsupported 'version', expected: #{expected}, but got: #{actual}."
  end

  EXTENSIONS_NOT_HASH = issue :EXTENSIONS_NOT_HASH, :actual do
    "The configuration file '#{semantic}' contains 'extensions', expected: Hash, but got: #{actual}."
  end

  EXTENSION_BINDING_NOT_HASH = issue :EXTENSION_BINDING_NOT_HASH, :extension, :actual do
    "The configuration file '#{semantic}' contains '#{extension}', expected: Hash, but got: #{actual}."
  end

  UNKNOWN_EXTENSION = issue :UNKNOWN_EXTENSION, :extension do
    "The configuration file '#{semantic}' contains the unknown extension: #{extension}."
  end
end
