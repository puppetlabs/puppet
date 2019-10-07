module Puppet::Pops
module Types
class PURIType < PAnyType

  # Tell evaluator that an members of instances of this type can be invoked using dot notation
  include TypeWithMembers

  SCHEME = 'scheme'.freeze
  USERINFO = 'userinfo'.freeze
  HOST = 'host'.freeze
  PORT = 'port'.freeze
  PATH = 'path'.freeze
  QUERY = 'query'.freeze
  FRAGMENT = 'fragment'.freeze
  OPAQUE = 'opaque'.freeze

  URI_MEMBERS = {
    SCHEME => AttrReader.new(SCHEME),
    USERINFO => AttrReader.new(USERINFO),
    HOST => AttrReader.new(HOST),
    PORT => AttrReader.new(PORT),
    PATH => AttrReader.new(PATH),
    QUERY => AttrReader.new(QUERY),
    FRAGMENT => AttrReader.new(FRAGMENT),
    OPAQUE => AttrReader.new(OPAQUE),
  }

  TYPE_URI_INIT_HASH = TypeFactory.struct(
    TypeFactory.optional(SCHEME) => PStringType::NON_EMPTY,
    TypeFactory.optional(USERINFO) => PStringType::NON_EMPTY,
    TypeFactory.optional(HOST) => PStringType::NON_EMPTY,
    TypeFactory.optional(PORT) => PIntegerType.new(0),
    TypeFactory.optional(PATH) => PStringType::NON_EMPTY,
    TypeFactory.optional(QUERY) => PStringType::NON_EMPTY,
    TypeFactory.optional(FRAGMENT) => PStringType::NON_EMPTY,
    TypeFactory.optional(OPAQUE) => PStringType::NON_EMPTY,
  )

  TYPE_STRING_PARAM = TypeFactory.optional(PVariantType.new([
    PStringType::NON_EMPTY,
    PRegexpType::DEFAULT,
    TypeFactory.type_type(PPatternType::DEFAULT),
    TypeFactory.type_type(PEnumType::DEFAULT),
    TypeFactory.type_type(PNotUndefType::DEFAULT),
    TypeFactory.type_type(PUndefType::DEFAULT),
  ]))

  TYPE_INTEGER_PARAM = TypeFactory.optional(PVariantType.new([
    PIntegerType.new(0),
    TypeFactory.type_type(PNotUndefType::DEFAULT),
    TypeFactory.type_type(PUndefType::DEFAULT),
  ]))

  TYPE_URI_PARAM_HASH_TYPE = TypeFactory.struct(
    TypeFactory.optional(SCHEME) => TYPE_STRING_PARAM,
    TypeFactory.optional(USERINFO) => TYPE_STRING_PARAM,
    TypeFactory.optional(HOST) => TYPE_STRING_PARAM,
    TypeFactory.optional(PORT) => TYPE_INTEGER_PARAM,
    TypeFactory.optional(PATH) => TYPE_STRING_PARAM,
    TypeFactory.optional(QUERY) => TYPE_STRING_PARAM,
    TypeFactory.optional(FRAGMENT) => TYPE_STRING_PARAM,
    TypeFactory.optional(OPAQUE) => TYPE_STRING_PARAM,
  )

  TYPE_URI_PARAM_TYPE = PVariantType.new([PStringType::NON_EMPTY, TYPE_URI_PARAM_HASH_TYPE])

  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'AnyType',
      {
        'parameters' => { KEY_TYPE => TypeFactory.optional(TYPE_URI_PARAM_TYPE), KEY_VALUE => nil }
      }
    )
  end

  def self.new_function(type)
    @new_function ||= Puppet::Functions.create_loaded_function(:new_error, type.loader) do
      dispatch :create do
        param 'String[1]', :uri
      end

      dispatch :from_hash do
        param TYPE_URI_INIT_HASH, :hash
      end

      def create(uri)
        URI.parse(uri)
      end

      def from_hash(init_hash)
        sym_hash = {}
        init_hash.each_pair { |k, v| sym_hash[k.to_sym] = v }
        scheme = sym_hash[:scheme]
        scheme_class = scheme.nil? ? URI::Generic : (URI.scheme_list[scheme.upcase] || URI::Generic)
        scheme_class.build(sym_hash)
      end
    end
  end

  attr_reader :parameters

  def initialize(parameters = nil)
    if parameters.is_a?(String)
      parameters = TypeAsserter.assert_instance_of('URI-Type parameter', Pcore::TYPE_URI, parameters, true)
      @parameters = uri_to_hash(URI.parse(parameters))
    elsif parameters.is_a?(URI)
      @parameters = uri_to_hash(parameters)
    elsif parameters.is_a?(Hash)
      params = TypeAsserter.assert_instance_of('URI-Type parameter', TYPE_URI_PARAM_TYPE, parameters, true)
      @parameters = params.empty? ? nil : params
    end
  end

  def eql?(o)
    self.class == o.class && @parameters == o.parameters
  end

  def ==(o)
    eql?(o)
  end

  def [](key)
    URI_MEMBERS[key]
  end

  def generalize
    DEFAULT
  end

  def hash
    self.class.hash ^ @parameters.hash
  end

  def instance?(o, guard = nil)
    return false unless o.is_a?(URI)
    return true if @parameters.nil?

    eval = Parser::EvaluatingParser.singleton.evaluator
    @parameters.keys.all? { |pn| eval.match?(o.send(pn), @parameters[pn]) }
  end

  def roundtrip_with_string?
    true
  end

  def _pcore_init_hash
    @parameters == nil? ? EMPTY_HASH : { 'parameters' => @parameters }
  end

  protected

  def _assignable?(o, guard = nil)
    return false unless o.class == self.class
    return true if @parameters.nil?
    o_params = o.parameters || EMPTY_HASH

    eval = Parser::EvaluatingParser.singleton.evaluator
    @parameters.keys.all? do |pn|
      if o_params.include?(pn)
        a = o_params[pn]
        b = @parameters[pn]
        eval.match?(a, b) || a.is_a?(PAnyType) && b.is_a?(PAnyType) && b.assignable?(a)
      else
        false
      end
    end
  end

  private

  def uri_to_hash(uri)
    result = {}
    scheme = uri.scheme
    unless scheme.nil?
      scheme = scheme.downcase
      result[SCHEME] = scheme
    end
    result[USERINFO] = uri.userinfo unless uri.userinfo.nil?
    result[HOST] = uri.host.downcase unless uri.host.nil?
    result[PORT] = uri.port.to_s unless uri.port.nil? || uri.port == 80 && 'http' == scheme || uri.port == 443 && 'https' == scheme
    result[PATH] = uri.path unless uri.path.nil? || uri.path.empty?
    result[QUERY] = uri.query unless uri.query.nil?
    result[FRAGMENT] = uri.fragment unless uri.fragment.nil?
    result[OPAQUE] = uri.opaque unless uri.opaque.nil?
    result.empty? ? nil : result
  end

  DEFAULT = PURIType.new(nil)
end
end
end
