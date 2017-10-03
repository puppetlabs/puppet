module Puppet::Pops
module Types
class PErrorType < PAnyType
  DEFAULT_ISSUE_CODE = 'ERROR'.freeze

  class Error
    include PuppetObject

    attr_reader :message, :kind, :issue_code, :partial_result, :details

    def self._pcore_type
      return PErrorType::DEFAULT
    end

    def initialize(message, kind = nil, issue_code = DEFAULT_ISSUE_CODE, partial_result = nil, details = nil)
      @issue_code = issue_code
      @kind = kind
      @message = message
      @partial_result = partial_result
      @details = details
    end

    def to_s
      s = 'Error('
      s << StringConverter.convert(_pcore_init_hash, '%p')
      s << ')'
      s
    end

    def _pcore_type
      return PErrorType.new(@kind.nil? ? nil : PStringType.new(@kind), @issue_code.nil? ? nil : PStringType.new(@issue_code))
    end

    def _pcore_init_hash
      hash = {
        'message' => @message,
      }
      hash['kind'] = @kind unless @kind.nil?
      hash['issue_code'] = @issue_code unless @issue_code.nil?
      hash['partial_result'] = @partial_result unless @partial_result.nil?
      hash['details'] = @details unless @details.nil?
      hash
    end
  end

  TYPE_ERROR_TYPE_PARAM = PVariantType.new([PTypeType.new(PEnumType::DEFAULT), PTypeType.new(PPatternType::DEFAULT)])
  TYPE_ERROR_PARAM = PVariantType.new([PUndefType::DEFAULT, PDefaultType::DEFAULT, PRegexpType::DEFAULT, PStringType::DEFAULT, TYPE_ERROR_TYPE_PARAM])

  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'AnyType',
      'kind' => { KEY_TYPE => TYPE_ERROR_PARAM, KEY_VALUE => nil },
      'issue_code' => { KEY_TYPE => TYPE_ERROR_PARAM, KEY_VALUE => nil }
    )
  end

  def self.new_function(type)
    @new_function ||= Puppet::Functions.create_loaded_function(:new_error, type.loader) do
      dispatch :create do
        param 'String[1]', :message
        optional_param 'Optional[String[1]]', :kind
        optional_param 'Optional[String[1]]', :issue_code
        optional_param 'Data', :partial_result
        optional_param 'Optional[DataHash]', :details
      end

      def create(message, kind = nil, issue_code = nil, partial_result = nil, details = nil)
        issue_code = DEFAULT_ISSUE_CODE if issue_code.nil?
        Error.new(message, kind, issue_code, partial_result, details)
      end
    end
  end

  attr_reader :kind, :issue_code

  def initialize(kind = nil, issue_code = nil)
    @kind = convert_arg(kind)
    @issue_code = convert_arg(issue_code)
  end

  def eql?(o)
    self.class == o.class && @kind == o.kind && @issue_code == o.issue_code
  end

  def generalize
    DEFAULT
  end

  def hash
    self.class.hash ^ @kind.hash ^ @issue_code.hash
  end

  def instance?(o, guard = nil)
    if o.is_a?(Error)
      unless @kind.nil?
        return false unless @kind.instance?(o.kind)
      end
      unless @issue_code.nil?
        return false unless @issue_code.instance?(o.issue_code)
      end
      true
    else
      false
    end
  end

  def normalize(guard = nil)
    nk = @kind.nil? ? nil : @kind.normalize(guard)
    ni = @issue_code.nil? ? nil : @issue_code.normalize(guard)
    nk.equal?(@kind) && ni.equal?(@issue_code) ? self : new(nk, ni)
  end

  protected

  def _assignable?(o, guard = nil)
    if o.class == self.class
      unless @kind.nil?
        return false unless o.kind && @kind.assignable?(o.kind, guard)
      end
      unless @issue_code.nil?
        return false unless o.issue_code && @issue_code.assignable?(o.issue_code)
      end
      true
    else
      false
    end
  end

  private

  def convert_arg(arg)
    case arg
    when nil, :default
      nil
    when String
      PStringType.new(arg)
    when Regexp
      PPatternType.new([PRegexpType.new(arg)])
    else
      arg
    end
  end

  DEFAULT = PErrorType.new(nil, nil)
end
end
end
