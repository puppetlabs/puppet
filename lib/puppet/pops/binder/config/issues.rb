module Puppet::Pops::Binder::Config::Issues
  # (see Puppet::Pops::Issues#issue)
  def self.issue (issue_code, *args, &block)
    Puppet::Pops::Issues.issue(issue_code, *args, &block)
  end

  CONFIG_IS_NOT_ARRAY = issue :CONFIG_IS_NOT_ARRAY do
    "The configuration file '#{semantic}' has no array at the top level"
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

end
