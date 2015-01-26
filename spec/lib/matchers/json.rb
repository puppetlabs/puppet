module JSONMatchers
  class SetJsonAttribute
    def initialize(attributes)
      @attributes = attributes
    end

    def format
      @format ||= Puppet::Network::FormatHandler.format('pson')
    end

    def json(instance)
      PSON.parse(instance.to_pson)
    end

    def attr_value(attrs, instance)
      attrs = attrs.dup
      hash = json(instance)
      while attrs.length > 0
        name = attrs.shift
        hash = hash[name]
      end
      hash
    end

    def to(value)
      @value = value
      self
    end

    def matches?(instance)
      result = attr_value(@attributes, instance)
      if @value
        result == @value
      else
        ! result.nil?
      end
    end

    def failure_message(instance)
      if @value
        "expected #{instance.inspect} to set #{@attributes.inspect} to #{@value.inspect}; got #{attr_value(@attributes, instance).inspect}"
      else
        "expected #{instance.inspect} to set #{@attributes.inspect} but was nil"
      end
    end

    def failure_message_when_negated(instance)
      if @value
        "expected #{instance.inspect} not to set #{@attributes.inspect} to #{@value.inspect}"
      else
        "expected #{instance.inspect} not to set #{@attributes.inspect} to nil"
      end
    end
  end

  class ReadJsonAttribute
    def initialize(attribute)
      @attribute = attribute
    end

    def format
      @format ||= Puppet::Network::FormatHandler.format('pson')
    end

    def from(value)
      @json = value
      self
    end

    def as(as)
      @value = as
      self
    end

    def matches?(klass)
      raise "Must specify json with 'from'" unless @json

      @instance = format.intern(klass, @json)
      if @value
        @instance.send(@attribute) == @value
      else
        ! @instance.send(@attribute).nil?
      end
    end

    def failure_message(klass)
      if @value
        "expected #{klass} to read #{@attribute} from #{@json} as #{@value.inspect}; got #{@instance.send(@attribute).inspect}"
      else
        "expected #{klass} to read #{@attribute} from #{@json} but was nil"
      end
    end

    def failure_message_when_negated(klass)
      if @value
        "expected #{klass} not to set #{@attribute} to #{@value}"
      else
        "expected #{klass} not to set #{@attribute} to nil"
      end
    end
  end

  if !Puppet.features.microsoft_windows?
    require 'json'
    require 'json-schema'

    class SchemaMatcher
      JSON_META_SCHEMA = JSON.parse(File.read('api/schemas/json-meta-schema.json'))

      def initialize(schema)
        @schema = schema
      end

      def matches?(json)
        JSON::Validator.validate!(JSON_META_SCHEMA, @schema)
        JSON::Validator.validate!(@schema, json)
      end
    end
  end

  def validate_against(schema_file)
    if Puppet.features.microsoft_windows?
      pending("Schema checks cannot be done on windows because of json-schema problems")
    else
      schema = JSON.parse(File.read(schema_file))
      SchemaMatcher.new(schema)
    end
  end

  def set_json_attribute(*attributes)
    SetJsonAttribute.new(attributes)
  end

  def read_json_attribute(attribute)
    ReadJsonAttribute.new(attribute)
  end
end
