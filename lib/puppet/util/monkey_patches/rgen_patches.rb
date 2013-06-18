require 'rgen/array_extensions'

# This monkey-patch is required because of the quirky way Ruby handles implicit conversion from Array to
# a Hash or a String. Instead of checking if the class implements #to_hash or #to_string a call is made and
# it is expected to fail with a NoMethod error.
# Naturally, combining this with #method_missing will not work well.
#
# The #method_missing method below is a fixed version of the RGen array_extensions.rb with a fix for :to_str (the same
# way as #to_hash is handled).
#
# This monkey patch should be removed once this fix is in RGen (> 0.6.2).
#
class Array

  def method_missing(m, *args)

  # This extensions has the side effect that it allows to call any method on any
  # empty array with an empty array as the result. This behavior is required for
  # navigating models.
  #
  # This is a problem for Hash[] called with an (empty) array of tupels.
  # It will call to_hash expecting a Hash as the result. When it gets an array instead,
  # it fails with an exception. Make sure it gets a NoMethodException as without this
  # extension and it will catch that and return an empty hash as expected.
  #
  return super unless (size == 0 &&
    !(m == :to_hash || m == :to_str)) ||
    compact.any?{|e| e.is_a? RGen::MetamodelBuilder::MMBase}
  # use an array to build the result to achiev similar ordering
  result = []
  inResult = {}
  compact.each do |e|
    if e.is_a? RGen::MetamodelBuilder::MMBase
      ((o=e.send(m)).is_a?(Array) ? o : [o] ).each do |v|
        next if inResult[v.object_id]
        inResult[v.object_id] = true
        result << v
      end
    else
      raise StandardError.new("Trying to call a method on an array element not a RGen MMBase")
    end
  end
  result.compact
  end
end