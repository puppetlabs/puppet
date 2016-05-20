module Puppet::Pops
module Types

KEY_ANNOTATIONS = 'annotations'.freeze

# Behaviour common to all Pcore annotatable classes
#
# @api public
module Annotatable
  TYPE_ANNOTATION_KEY_TYPE = PType::DEFAULT # TBD
  TYPE_ANNOTATION_VALUE_TYPE = PStructType::DEFAULT #TBD
  TYPE_ANNOTATIONS = PHashType.new(TYPE_ANNOTATION_KEY_TYPE, TYPE_ANNOTATION_VALUE_TYPE)

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
