RSpec::Matchers.define :set_json_attribute do |*attributes|
  def format
    @format ||= Puppet::Network::FormatHandler.format('pson')
  end

  chain :to do |value|
    @value = value
  end

  def json(instance)
    PSON.parse(instance.to_pson)
  end

  def attr_value(attrs, instance)
    attrs = attrs.dup
    hash = json(instance)['data']
    while attrs.length > 0
      name = attrs.shift
      hash = hash[name]
    end
    hash
  end

  match do |instance|
    result = attr_value(attributes, instance)
    if @value
      result == @value
    else
      ! result.nil?
    end
  end

  failure_message_for_should do |instance|
    if @value
      "expected #{instance.inspect} to set #{attributes.inspect} to #{@value.inspect}; got #{attr_value(attributes, instance).inspect}"
    else
      "expected #{instance.inspect} to set #{attributes.inspect} but was nil"
    end
  end

  failure_message_for_should_not do |instance|
    if @value
      "expected #{instance.inspect} not to set #{attributes.inspect} to #{@value.inspect}"
    else
      "expected #{instance.inspect} not to set #{attributes.inspect} to nil"
    end
  end
end

RSpec::Matchers.define :set_json_document_type_to do |type|
  def format
    @format ||= Puppet::Network::FormatHandler.format('pson')
  end

  match do |instance|
    json(instance)['document_type'] == type
  end

  def json(instance)
    PSON.parse(instance.to_pson)
  end

  failure_message_for_should do |instance|
    "expected #{instance.inspect} to set document_type to #{type.inspect}; got #{json(instance)['document_type'].inspect}"
  end

  failure_message_for_should_not do |instance|
    "expected #{instance.inspect} not to set document_type to #{type.inspect}"
  end
end

RSpec::Matchers.define :read_json_attribute do |attribute|
  def format
    @format ||= Puppet::Network::FormatHandler.format('pson')
  end

  chain :from do |value|
    @json = value
  end

  chain :as do |as|
    @value = as
  end

  match do |klass|
    raise "Must specify json with 'from'" unless @json

    @instance = format.intern(klass, @json)
    if @value
      @instance.send(attribute) == @value
    else
      ! @instance.send(attribute).nil?
    end
  end

  failure_message_for_should do |klass|
    if @value
      "expected #{klass} to read #{attribute} from #{@json} as #{@value.inspect}; got #{@instance.send(attribute).inspect}"
    else
      "expected #{klass} to read #{attribute} from #{@json} but was nil"
    end
  end

  failure_message_for_should_not do |klass|
    if @value
      "expected #{klass} not to set #{attribute} to #{@value}"
    else
      "expected #{klass} not to set #{attribute} to nil"
    end
  end
end
