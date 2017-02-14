module Puppet::Pops
module Types

KEY_ANNOTATIONS = 'annotations'.freeze

# Behaviour common to all Pcore annotatable classes
#
# @api public
module Annotatable
  TYPE_ANNOTATIONS = PHashType.new(PType.new(PTypeReferenceType.new('Annotation')), PHashType::DEFAULT)

  # @return [{PType => PStructType}] the map of annotations
  # @api public
  attr_reader :annotations

  # @api private
  def init_annotatable(i12n_hash)
    @annotations = i12n_hash[KEY_ANNOTATIONS].freeze
  end

  # @api private
  def annotatable_accept(visitor, guard)
    @annotations.each_key { |key| key.accept(visitor, guard) } unless @annotations.nil?
  end

  # @api private
  def i12n_hash
    result = {}
    result[KEY_ANNOTATIONS] = @annotations unless @annotations.nil?
    result
  end
end
end
end
