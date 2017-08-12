require 'yaml'

module Puppet::Util::Yaml
  if defined?(::Psych::SyntaxError)
    YamlLoadExceptions = [::StandardError, ::Psych::SyntaxError]
  else
    YamlLoadExceptions = [::StandardError]
  end

  class YamlLoadError < Puppet::Error; end

  def self.disallowed_class(cls)
    raise YamlLoadError, "Tried to load unspecified class: #{cls}"
  end

  def self.safe_load(yaml, allowed_classes = [], filename = nil)
    @psych_safe_load ||= Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.1.0')
    return YAML.safe_load(yaml, allowed_classes, [], false, filename) if @psych_safe_load

    # emulate needed parts of YAML.safe_load for rubies < 2.1.0
    data = YAML.parse(yaml, filename)

    # safe_load returns false for empty yaml
    return false unless data.is_a?(Psych::Nodes::Document)

    @known_tags ||= {
      'encoding' => :skip,
      'range' => Range,
      'regexp' => Regexp,
      'sym' => Symbol,
      'symbol' => Symbol,
      'array' => :arg,
      'hash' => :arg,
      'struct' => :arg,
      'object' => :arg,
    }.freeze

    # raise errors for tags that will cause load of disallowed classes
    allowed_class_names = allowed_classes.map { |cls| cls.name }
    data.root.each do |o|
      next unless o.tag && o.tag =~ /\A!ruby\/([^:]+)(?::(.*))\z/
      tag = $1
      arg = $2
      class_name = @known_tags[tag]
      disallowed_class(tag) if class_name.nil?

      next if class_name == :skip
      class_name = arg if class_name == :arg
      disallowed_class(class_name) unless allowed_class_names.include?(class_name)
    end
    data.to_ruby
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
