require "yaml"

# This needs to be defined up front in case any internal classes need to base
# their behavior off of this.
module SafeYAML
  YAML_ENGINE = defined?(YAML::ENGINE) ? YAML::ENGINE.yamler : "syck"
end

require "set"
require "safe_yaml/deep"
require "safe_yaml/parse/hexadecimal"
require "safe_yaml/parse/sexagesimal"
require "safe_yaml/parse/date"
require "safe_yaml/transform/transformation_map"
require "safe_yaml/transform/to_boolean"
require "safe_yaml/transform/to_date"
require "safe_yaml/transform/to_float"
require "safe_yaml/transform/to_integer"
require "safe_yaml/transform/to_nil"
require "safe_yaml/transform/to_symbol"
require "safe_yaml/transform"
require "safe_yaml/resolver"
require "safe_yaml/syck_hack" if defined?(JRUBY_VERSION)

module SafeYAML
  MULTI_ARGUMENT_YAML_LOAD = YAML.method(:load).arity != 1

  DEFAULT_OPTIONS = Deep.freeze({
    :default_mode         => nil,
    :suppress_warnings    => false,
    :deserialize_symbols  => false,
    :whitelisted_tags     => [],
    :custom_initializers  => {},
    :raise_on_unknown_tag => false
  })

  OPTIONS = Deep.copy(DEFAULT_OPTIONS)

  module_function
  def restore_defaults!
    OPTIONS.clear.merge!(Deep.copy(DEFAULT_OPTIONS))
  end

  def tag_safety_check!(tag, options)
    return if tag.nil? || tag == "!"
    if options[:raise_on_unknown_tag] && !options[:whitelisted_tags].include?(tag) && !tag_is_explicitly_trusted?(tag)
      raise "Unknown YAML tag '#{tag}'"
    end
  end

  def whitelist!(*classes)
    classes.each do |klass|
      whitelist_class!(klass)
    end
  end

  def whitelist_class!(klass)
    raise "#{klass} not a Class" unless klass.is_a?(::Class)

    klass_name = klass.name
    raise "#{klass} cannot be anonymous" if klass_name.nil? || klass_name.empty?

    # Whitelist any built-in YAML tags supplied by Syck or Psych.
    predefined_tag = predefined_tags[klass]
    if predefined_tag
      OPTIONS[:whitelisted_tags] << predefined_tag
      return
    end

    # Exception is exceptional (har har).
    tag_class  = klass < Exception ? "exception" : "object"

    tag_prefix = case YAML_ENGINE
                 when "psych" then "!ruby/#{tag_class}"
                 when "syck"  then "tag:ruby.yaml.org,2002:#{tag_class}"
                 else raise "unknown YAML_ENGINE #{YAML_ENGINE}"
                 end
    OPTIONS[:whitelisted_tags] << "#{tag_prefix}:#{klass_name}"
  end

  def predefined_tags
    if @predefined_tags.nil?
      @predefined_tags = {}

      if YAML_ENGINE == "syck"
        YAML.tagged_classes.each do |tag, klass|
          @predefined_tags[klass] = tag
        end

      else
        # Special tags appear to be hard-coded in Psych:
        # https://github.com/tenderlove/psych/blob/v1.3.4/lib/psych/visitors/to_ruby.rb
        # Fortunately, there aren't many that SafeYAML doesn't already support.
        @predefined_tags.merge!({
          Exception => "!ruby/exception",
          Range     => "!ruby/range",
          Regexp    => "!ruby/regexp",
        })
      end
    end

    @predefined_tags
  end

  if YAML_ENGINE == "psych"
    def tag_is_explicitly_trusted?(tag)
      false
    end

  else
    TRUSTED_TAGS = Set.new([
      "tag:yaml.org,2002:binary",
      "tag:yaml.org,2002:bool#no",
      "tag:yaml.org,2002:bool#yes",
      "tag:yaml.org,2002:float",
      "tag:yaml.org,2002:float#fix",
      "tag:yaml.org,2002:int",
      "tag:yaml.org,2002:map",
      "tag:yaml.org,2002:null",
      "tag:yaml.org,2002:seq",
      "tag:yaml.org,2002:str",
      "tag:yaml.org,2002:timestamp",
      "tag:yaml.org,2002:timestamp#ymd"
    ]).freeze

    def tag_is_explicitly_trusted?(tag)
      TRUSTED_TAGS.include?(tag)
    end
  end
end

module YAML
  def self.load_with_options(yaml, *original_arguments)
    filename, options = filename_and_options_from_arguments(original_arguments)
    safe_mode = safe_mode_from_options("load", options)
    arguments = [yaml]

    if safe_mode == :safe
      arguments << filename if SafeYAML::YAML_ENGINE == "psych"
      arguments << options_for_safe_load(options)
      safe_load(*arguments)
    else
      arguments << filename if SafeYAML::MULTI_ARGUMENT_YAML_LOAD
      unsafe_load(*arguments)
    end
  end

  def self.load_file_with_options(file, options={})
    safe_mode = safe_mode_from_options("load_file", options)
    if safe_mode == :safe
      safe_load_file(file, options_for_safe_load(options))
    else
      unsafe_load_file(file)
    end
  end

  if SafeYAML::YAML_ENGINE == "psych"
    require "safe_yaml/psych_handler"
    require "safe_yaml/psych_resolver"
    require "safe_yaml/safe_to_ruby_visitor"

    def self.safe_load(yaml, filename=nil, options={})
      # If the user hasn't whitelisted any tags, we can go with this implementation which is
      # significantly faster.
      if (options && options[:whitelisted_tags] || SafeYAML::OPTIONS[:whitelisted_tags]).empty?
        safe_handler = SafeYAML::PsychHandler.new(options)
        arguments_for_parse = [yaml]
        arguments_for_parse << filename if SafeYAML::MULTI_ARGUMENT_YAML_LOAD
        Psych::Parser.new(safe_handler).parse(*arguments_for_parse)
        return safe_handler.result || false

      else
        safe_resolver = SafeYAML::PsychResolver.new(options)
        tree = SafeYAML::MULTI_ARGUMENT_YAML_LOAD ?
          Psych.parse(yaml, filename) :
          Psych.parse(yaml)
        return safe_resolver.resolve_node(tree)
      end
    end

    def self.safe_load_file(filename, options={})
      File.open(filename, 'r:bom|utf-8') { |f| self.safe_load(f, filename, options) }
    end

    def self.unsafe_load_file(filename)
      if SafeYAML::MULTI_ARGUMENT_YAML_LOAD
        # https://github.com/tenderlove/psych/blob/v1.3.2/lib/psych.rb#L296-298
        File.open(filename, 'r:bom|utf-8') { |f| self.unsafe_load(f, filename) }
      else
        # https://github.com/tenderlove/psych/blob/v1.2.2/lib/psych.rb#L231-233
        self.unsafe_load File.open(filename)
      end
    end

  else
    require "safe_yaml/syck_resolver"
    require "safe_yaml/syck_node_monkeypatch"

    def self.safe_load(yaml, options={})
      resolver = SafeYAML::SyckResolver.new(SafeYAML::OPTIONS.merge(options || {}))
      tree = YAML.parse(yaml)
      return resolver.resolve_node(tree)
    end

    def self.safe_load_file(filename, options={})
      File.open(filename) { |f| self.safe_load(f, options) }
    end

    def self.unsafe_load_file(filename)
      # https://github.com/indeyets/syck/blob/master/ext/ruby/lib/yaml.rb#L133-135
      File.open(filename) { |f| self.unsafe_load(f) }
    end
  end

  class << self
    alias_method :unsafe_load, :load
    alias_method :load, :load_with_options
    alias_method :load_file, :load_file_with_options

    private
    def filename_and_options_from_arguments(arguments)
      if arguments.count == 1
        if arguments.first.is_a?(String)
          return arguments.first, {}
        else
          return nil, arguments.first || {}
        end

      else
        return arguments.first, arguments.last || {}
      end
    end

    def safe_mode_from_options(method, options={})
      if options[:safe].nil?
        safe_mode = SafeYAML::OPTIONS[:default_mode] || :safe
        if SafeYAML::OPTIONS[:default_mode].nil? && !SafeYAML::OPTIONS[:suppress_warnings]
          Kernel.warn "Called '#{method}' without the :safe option -- defaulting to #{safe_mode} mode."
          SafeYAML::OPTIONS[:suppress_warnings] = true
        end
        return safe_mode
      end

      options[:safe] ? :safe : :unsafe
    end

    def options_for_safe_load(base_options)
      options = base_options.dup
      options.delete(:safe)
      options
    end
  end
end
