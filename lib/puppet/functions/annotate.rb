# Handles annotations on objects. The function can be used in four different ways.
#
# With two arguments, an `Annotation` type and an object, the function returns the annotation
# for the object of the given type, or `undef` if no such annotation exists.
#
# @example Using `annotate` with two arguments
#
# ```puppet
# $annotation = Mod::NickNameAdapter.annotate(o)
#
# $annotation = annotate(Mod::NickNameAdapter.annotate, o)
# ```
#
# With three arguments, an `Annotation` type, an object, and a block, the function returns the
# annotation for the object of the given type, or annotates it with a new annotation initialized
# from the hash returned by the given block when no such annotation exists. The block will not
# be called when an annotation of the given type is already present.
#
# @example Using `annotate` with two arguments and a block
#
# ```puppet
# $annotation = Mod::NickNameAdapter.annotate(o) || { { 'nick_name' => 'Buddy' } }
#
# $annotation = annotate(Mod::NickNameAdapter.annotate, o) || { { 'nick_name' => 'Buddy' } }
# ```
#
# With three arguments, an `Annotation` type, an object, and an `Hash`, the function will annotate
# the given object with a new annotation of the given type that is initialized from the given hash.
# An existing annotation of the given type is discarded.
#
# @example Using `annotate` with three arguments where third argument is a Hash
#
# ```puppet
# $annotation = Mod::NickNameAdapter.annotate(o, { 'nick_name' => 'Buddy' })
#
# $annotation = annotate(Mod::NickNameAdapter.annotate, o, { 'nick_name' => 'Buddy' })
# ```
#
# With three arguments, an `Annotation` type, an object, and an the string `clear`, the function will
# clear the annotation of the given type in the given object. The old annotation is returned if
# it existed.
#
# @example Using `annotate` with three arguments where third argument is the string 'clear'
#
# ```puppet
# $annotation = Mod::NickNameAdapter.annotate(o, clear)
#
# $annotation = annotate(Mod::NickNameAdapter.annotate, o, clear)
# ```
#
# With three arguments, the type `Pcore`, an object, and a Hash of hashes keyed by `Annotation` types,
# the function will annotate the given object with all types used as keys in the given hash. Each annotation
# is initialized with the nested hash for the respective type. The annotated object is returned.
#
# @example Add multiple annotations to a new instance of `Mod::Person` using the `Pcore` type.
#
# ```puppet
#   $person = Pcore.annotate(Mod::Person({'name' => 'William'}), {
#     Mod::NickNameAdapter >= { 'nick_name' => 'Bill' },
#     Mod::HobbiesAdapter => { 'hobbies' => ['Ham Radio', 'Philatelist'] }
#   })
# ```
#
# @since 5.0.0
#
Puppet::Functions.create_function(:annotate) do
  dispatch :annotate do
    param 'Type[Annotation]', :type
    param 'Any', :value
    optional_block_param 'Callable[0, 0]', :block
  end

  dispatch :annotate_new do
    param 'Type[Annotation]', :type
    param 'Any', :value
    param 'Variant[Enum[clear],Hash[Pcore::MemberName,Any]]', :annotation_hash
  end

  dispatch :annotate_multi do
    param 'Type[Pcore]', :type
    param 'Any', :value
    param 'Hash[Type[Annotation], Hash[Pcore::MemberName,Any]]', :annotations
  end

  # @param type [Annotation] the annotation type
  # @param value [Object] the value to annotate
  # @param block [Proc] optional block to produce the annotation hash
  #
  def annotate(type, value, &block)
    type.implementation_class.annotate(value, &block)
  end

  # @param type [Annotation] the annotation type
  # @param value [Object] the value to annotate
  # @param annotation_hash [Hash{String => Object}] the annotation hash
  #
  def annotate_new(type, value, annotation_hash)
    type.implementation_class.annotate_new(value, annotation_hash)
  end

  # @param type [Type] the Pcore type
  # @param value [Object] the value to annotate
  # @param annotations [Hash{Annotation => Hash{String => Object}}] hash of annotation hashes
  #
  def annotate_multi(type, value, annotations)
    type.implementation_class.annotate(value, annotations)
  end
end
