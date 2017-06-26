module Puppet::Pops
module Types

KEY_ANNOTATIONS = 'annotations'.freeze

# Behaviour common to all Pcore annotatable classes
#
# @api public
module Annotatable
  TYPE_ANNOTATIONS = PHashType.new(PTypeType.new(PTypeReferenceType.new('Annotation')), PHashType::DEFAULT)

  # @return [{PTypeType => PStructType}] the map of annotations
  # @api public
  def annotations
    @annotations.nil? ? EMPTY_HASH : @annotations
  end

  # @api private
  def init_annotatable(init_hash)
    @annotations = init_hash[KEY_ANNOTATIONS].freeze
  end

  # @api private
  def annotatable_accept(visitor, guard)
    @annotations.each_key { |key| key.accept(visitor, guard) } unless @annotations.nil?
  end

  # @api private
  def _pcore_init_hash
    result = {}
    result[KEY_ANNOTATIONS] = @annotations unless @annotations.nil?
    result
  end
end
end
end
