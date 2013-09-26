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

  # Format 2 Only
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

  WRONG_VERSION = issue :WRONG_VERSION, :expected, :actual do
    "The configuration file '#{semantic}' has the wrong version, expected: #{expected}, actual: #{actual}"
  end

  INCOMPATIBLE_VERSION = issue :INCOMPATIBLE_VERSION, :expected, :actual do
    "The configuration file '#{semantic}' has incompatible version, expected: #{expected}, actual: #{actual}"
  end

  LATER_VERSION = issue :LATER_VERSION, :expected, :actual do
    "The configuration file '#{semantic}' has a version that is newer (features may not work), expected: #{expected}, actual: #{actual}"
  end

  DEPRECATED_VERSION = issue :DEPRECATED_VERSION, :deprecated, :latest do
    "The configuration file format version of '#{semantic}' is deprecated '#{deprecated}', please update to latest format '#{latest}"
  end

  HIERARCHY_ENTRY_NOT_OBJECT = issue :HIERARCHY_ENTRY_NOT_OBJECT do
    "The configuration file '#{semantic}' contains an entry in 'hierarchy' that is not an Object/Hash"
  end

  HIERARCHY_ENTRY_MISSING_ATTRIBUTE = issue :HIERARCHY_ENTRY_MISSING_ATTRIBUTE, :name do
    "The configuration file '#{semantic}' contains an entry in 'hierarchy' is missing the required attribute '#{name}'."
  end

  UNKNOWN_CATEGORY_ATTRIBUTE = issue :UNKNOWN_CATEGORY_ATTRIBUTE, :name do
    "The configuration file '#{semantic}' contains an entry in 'hierarchy' with the unknown attribute '#{name}'."
  end

  ILLEGAL_VALUE_FOR_COMMON = issue :ILLEGAL_VALUE_FOR_COMMON, :value do
    "The configuration file '#{semantic}' the 'common' category should have no 'value', got the value: '#{value}'."
  end

  PATH_PATHS_EXCLUSIVE = issue :PATH_PATHS_EXCLUSIVE do
    "The configuration file '#{semantic}' has an entry in 'hierarchy' using both 'path' and 'paths' (mutually exclusive)."
  end

  CATEGORY_ATTR_WRONG_TYPE = issue :CATEGORY_ATTR_WRONG_TYPE, :name, :expected, :actual do
    "The configuration file '#{semantic}' has an entry in 'hierarchy' with name '#{name}' with wrong type, expected: '#{expected}', actual: '#{actual}'."
  end

  CATEGORY_ATTR_EMPTY = issue :CATEGORY_ATTR_EMPTY, :name do
    "The configuration file '#{semantic}' has an entry in 'hierarchy' with name '#{name}' that is empty."
  end

  CATEGORY_ATTR_ARRAY_ENTRY_EMPTY = issue :CATEGORY_ATTR_ARRAY_ENTRY_EMPTY, :name do
    "The configuration file '#{semantic}' has an entry in 'hierarchy' with name '#{name}' that is an array with an empty entry."
  end
end
