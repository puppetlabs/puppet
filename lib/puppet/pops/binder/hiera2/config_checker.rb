module Puppet::Pops::Binder::Hiera2

class ConfigChecker

  # Produces a config checker for the given version
  # This implementation suports config format 2 and 3.
  # @raises ArgumentError when the format is not 2 or 3
  # @api public
  #
  def self.validator(diagnostics, version)
    unless version == 2 || version == 3
      raise ArgumentError, "The ConfigChecker only supports versions 2 and 3. Got #{version}."
    end

    if version == 2
      ConfigChecker2.new(diagnostics)
    else
      ConfigChecker3.new(diagnostics)
    end
  end

  # NOTE: All of this would be so much easier if there was a general validator for a schema!
  #
  class AbstractChecker
    attr_reader :diagnostics

    # Create an instance with a diagnostic producer that will receive the result during validation
    # @param diangostics [DiagnosticProducer] The producer that will receive the diagnostic
    def initialize(diagnostics)
      @diagnostics = diagnostics
    end

    # Validate the consistency of the given data. Diagnostics will be emitted to the DiagnosticProducer
    # that was set when this checker was created
    #
    # @param data [Object] The data read from the config file
    # @param config_file [String] The full path of the file. Used in error messages
    def validate(data, config_file)
      if data.is_a?(Hash)
        # If the version is missing, it is not meaningful to continue
        return unless check_version(data['version'], config_file)

        # Call check for all top level entries
        self.top_level_attributes.each do |name|
          self.send("check_#{name}", data[name], config_file)
        end
      else
        diagnostics.accept(Issues::CONFIG_IS_NOT_HASH, config_file)
      end
    end

    def top_level_attributes
      []
    end

    def check_backends(backends, config_file)
      if !backends.is_a?(Array) || backends.empty?
        diagnostics.accept(Issues::MISSING_BACKENDS, config_file)
      end
    end

  end

  private

  # Validates the consistency of a Hiera2::Config format 2
  # @api private
  class ConfigChecker2 < AbstractChecker

    def top_level_attributes
      ['hierarchy', 'backends']
    end

    # Version is required and must be >= 2. A warning is issued if version > 2 as this checker is
    # for version 2 only.
    # @return [Boolean] false if it is meaningless to continue checking
    def check_version(version, config_file)
      if version.nil?
        # This is not hiera2 compatible
        diagnostics.accept(Issues::MISSING_VERSION, config_file)
        return false
      end
      unless version == 2
        # it may have a sane subset, hence a different error (configured as warning)
        diagnostics.accept(Issues::INCOMPATIBLE_VERSION, config_file, :expected => 2, :actual => version)
      end
      return true
    end

    def check_hierarchy(hierarchy, config_file)
      if !hierarchy.is_a?(Array) || hierarchy.empty?
        diagnostics.accept(Issues::MISSING_HIERARCHY, config_file)
      else
        hierarchy.each do |value|
          unless value.is_a?(Array) && value.length() == 3
            diagnostics.accept(Issues::CATEGORY_MUST_BE_THREE_ELEMENT_ARRAY, config_file)
          end
        end
      end
    end
  end

  # Validates the consistency of a Hiera2::Config format 3
  # @api private
  class ConfigChecker3 < AbstractChecker

    attr_reader :type_calculator

    def initialize(diagnostics)
      super
      @type_calculator = Puppet::Pops::Types::TypeCalculator.new
      types = Puppet::Pops::Types::TypeFactory
      @string_t = types.string()
      @array_of_string_t = types.array_of(types.string)
      @array_hash_literal_data_t = types.array_of(types.hash_of_data)
    end

    def top_level_attributes
      ['hierarchy', 'backends', 'datadir']
    end

    # Version is required and must be >= 2. A warning is issued if version > 2 as this checker is
    # for version 2 only.
    # @return [Boolean] false if it is meaningless to continue checking
    def check_version(version, config_file)
      if version.nil?
        # This is not hiera2 compatible
        diagnostics.accept(Issues::MISSING_VERSION, config_file)
        return false
      end
      unless version == 3
        # it may have a sane subset, hence a different error (configured as warning)
        diagnostics.accept(Issues::INCOMPATIBLE_VERSION, config_file, :expected => 2, :actual => version)
      end
      return true
    end

    def check_hierarchy(hierarchy, config_file)
      # The hierarchy may be an Array[String] which means a list of paths for the common category,
      # or an Array[Hash[String, Data]] with more detail per entry

      if !hierarchy.is_a?(Array) || hierarchy.empty?
        diagnostics.accept(Issues::MISSING_HIERARCHY, config_file)
      else
        hierarchy_type = type_calculator.infer(hierarchy)
        if type_calculator.assignable?(@array_of_string_t, hierarchy_type)
          hierarchy.each {|value| check_category_path(value, config_file) }
        elsif type_calculator.assignable?(@array_hash_literal_data_t, hierarchy_type)
          hierarchy.each {|value| check_category_entry(value, config_file) }
        else
          diagnostics.accept(Issues::HIERARCHY_WRONG_TYPE, config_file, {
            :expected1 => @array_of_string,
            :expected2 => @array_hash_literal_data,
            :actual => hierarchy_type
            })
        end
      end
    end

    def check_category_entry(category_hash, config_file)
      keys = ['category', 'value', 'path', 'paths']
      if category_hash.size == 0
        diagnostics.accept(Issues::EMPTY_CATEGORY_ENTRY, config_file)
        return
      end
      category_hash.keys.each do |key|
        unless keys.include?(key)
          diagnostics.accept(Issues::UNKNOWN_CATEGORY_ATTRIBUTE, config_file, {:name => key})
        end
      end

      # 'category' is required
      unless category_hash['category']
        diagnostics.accept(Issues::HIERARCHY_ENTRY_MISSING_ATTRIBUTE, config_file, {:name => 'category'})
      end

      if category_hash['category'] == 'common'
        unless category_hash['value'].nil?
          diagnostics.accept(Issues::ILLEGAL_VALUE_FOR_COMMON, config_file, {:value => category_hash['value'].to_s})
        end
      elsif !(v = category_hash['value']).nil?
        check_category_value(v, config_file)
      end

      if !category_hash['path'].nil? && !category_hash['paths'].nil?
        diagnostics.accept(Issues::PATH_PATHS_EXCLUSIVE, config_file)
      end

      if !(v = category_hash['path']).nil?
        check_category_path(v, config_file)
      end

      if !(v = category_hash['paths']).nil?
        check_category_paths(v, config_file)
      end

    end

    def check_attr_type(name, expected, actual, config_file)
      if !type_calculator.assignable?(expected, actual)
        diagnostics.accept(Issues::CATEGORY_ATTR_WRONG_TYPE, config_file,
        { :name => name,
          :expected => type_calculator.string(expected),
          :actual => type_calculator.string(actual)
        })
        false
      else
        true
      end
    end

    def check_non_empty_string(name, value, config_file)
      if check_attr_type(name, @string_t, type_calculator.infer(value), config_file )
        if value.empty?
          diagnostics.accept(Issues::CATEGORY_ATTR_EMPTY, config_file, :name => name)
        end
      end
    end

    def check_string(name, value, config_file)
      check_attr_type(name, @string_t, type_calculator.infer(value), config_file )
    end

    def check_non_empty_array_of_string(name, value, config_file)
      if check_attr_type(name, @array_of_string_t, type_calculator.infer(value), config_file )
        if value.empty?
          diagnostics.accept(Issues::CATEGORY_ATTR_EMPTY, config_file, :name => name)
        end
      end
      # elements (string) may not be empty
      value.each do |s|
        if s.empty?
          diagnostics.accept(Issues::CATEGORY_ATTR_ARRAY_ENTRY_EMPTY, config_file, :name => name)
        end
      end
    end

    def check_datadir(value, config_file)
      check_string('datadir', value, config_file) unless value.nil?
    end

    def check_category_path(value, config_file)
      check_non_empty_string('path', value, config_file)
    end

    def check_category_value(value, config_file)
      check_non_empty_string('value', value, config_file)
    end

    def check_category_paths(value, config_file)
      check_non_empty_array_of_string('paths', value, config_file)
    end
  end

end
end