# frozen_string_literal: true

# Unwraps a Sensitive value and returns the wrapped object.
# Returns the Value itself, if it is not Sensitive.
#
# @example Usage of unwrap
#
# ```puppet
# $plaintext = 'hunter2'
# $pw = Sensitive.new($plaintext)
# notice("Wrapped object is $pw") #=> Prints "Wrapped object is Sensitive [value redacted]"
# $unwrapped = $pw.unwrap
# notice("Unwrapped object is $unwrapped") #=> Prints "Unwrapped object is hunter2"
# ```
#
# You can optionally pass a block to unwrap in order to limit the scope where the
# unwrapped value is visible.
#
# @example Unwrapping with a block of code
#
# ```puppet
# $pw = Sensitive.new('hunter2')
# notice("Wrapped object is $pw") #=> Prints "Wrapped object is Sensitive [value redacted]"
# $pw.unwrap |$unwrapped| {
#   $conf = inline_template("password: ${unwrapped}\n")
#   Sensitive.new($conf)
# } #=> Returns a new Sensitive object containing an interpolated config file
# # $unwrapped is now out of scope
# ```
#
# @since 4.0.0
#
Puppet::Functions.create_function(:unwrap) do
  dispatch :from_sensitive do
    param 'Sensitive', :arg
    optional_block_param
  end

  dispatch :from_any do
    param 'Any', :arg
    optional_block_param
  end

  def from_sensitive(arg)
    unwrapped = arg.unwrap
    if block_given?
      yield(unwrapped)
    else
      unwrapped
    end
  end

  def from_any(arg)
    unwrapped = arg
    if block_given?
      yield(unwrapped)
    else
      unwrapped
    end
  end
end
