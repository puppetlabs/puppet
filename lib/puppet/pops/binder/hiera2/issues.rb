module Puppet::Pops::Binder::Hiera2::Issues
  # (see Puppet::Pops::Issues#issue)
  def self.issue (issue_code, *args, &block)
    Puppet::Pops::Issues.issue(issue_code, *args, &block)
  end

  CONFIG_IS_NOT_HASH = issue :CONFIG_IS_NOT_HASH do
    "The configuration file '#{semantic}' has no hash at the top level"
  end

  MISSING_HIERARCHY = issue :MISSING_HIERARCHY do
    "The configuration file '#{semantic}' contains no hierarchy"
  end

  MISSING_BACKENDS = issue :MISSING_BACKENDS do
    "The configuration file '#{semantic}' contains no backends"
  end

  CATEGORY_MUST_BE_THREE_ELEMENT_ARRAY = issue :CATEGORY_MUST_BE_THREE_ELEMENT_ARRAY do
    "The configuration file '#{semantic}' has a malformed hierarchy (should consist of arrays with three string entries)"
  end

  CONFIG_FILE_NOT_FOUND = issue :CONFIG_FILE_NOT_FOUND do
    "The configuration file '#{semantic}' does not exist"
  end

  CONFIG_FILE_SYNTAX_ERROR = issue :CONFIG_FILE_SYNTAX_ERROR do
    "Unable to parse: #{semantic}"
  end

  CANNOT_LOAD_BACKEND = issue :CANNOT_LOAD_BACKEND, :key, :error do
    "Backend '#{key}' in configuration file '#{semantic}' cannot be loaded: #{error}"
  end

  BACKEND_FILE_DOES_NOT_DEFINE_CLASS = issue :BACKEND_FILE_DOES_NOT_DEFINE_CLASS, :class_name do
    "The file '#{semantic}' does not define class #{class_name}"
  end

  NOT_A_BACKEND_CLASS = issue :NOT_A_BACKEND_CLASS, :key, :class_name do
    "Class #{class_name}, loaded using key #{key} in file '#{semantic}' is not a subclass of Backend"
  end

  METADATA_JSON_NOT_FOUND = issue :METADATA_JSON_NOT_FOUND do
    "The metadata file '#{semantic}' does not exist"
  end

  UNSUPPORTED_STRING_EXPRESSION = issue :UNSUPPORTED_STRING_EXPRESSION, :expr do
    "String '#{semantic}' contains an unsupported expression (type was #{expr.class.name})"
  end

  UNRESOLVED_STRING_VARIABLE = issue :UNRESOLVED_STRING_VARIABLE, :key do
    "Variable '#{key}' found in string '#{semantic}' cannot be resolved"
  end

  MISSING_VERSION = issue :MISSING_VERSION do
    "The configuration file '#{semantic}' does not have a version."
  end

  WRONG_VERSION = issue :WRONG_VERSION do
    "The configuration file '#{semantic}' has the wrong version, expected: #{expected}, actual: #{actual}"
  end

  LATER_VERSION = issue :LATER_VERSION do
    "The configuration file '#{semantic}' has a version that is newer (features may not work), expected: #{expected}, actual: #{actual}"
  end

end
