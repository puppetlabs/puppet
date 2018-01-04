# The base class for all of the leaves of the parse trees.  These
# basically just have types and values.  Both of these parameters
# are simple values, not AST objects.
#
class Puppet::Parser::AST::Leaf < Puppet::Parser::AST
  attr_accessor :value, :type
  # Return our value.
  def evaluate(scope)
    @value
  end

  def match(value)
    @value == value
  end

  def to_s
    @value.to_s unless @value.nil?
  end
end

# Host names, either fully qualified or just the short name, or even a regex
#
class Puppet::Parser::AST::HostName < Puppet::Parser::AST::Leaf
  def initialize(hash)
    super

    # Note that this is an AST::Regex, not a Regexp
    unless @value.is_a?(Regex)
      @value = @value.to_s.downcase
      if @value =~ /[^-\w.]/
        raise Puppet::DevError, _("'%{value}' is not a valid hostname") % { value: @value }
      end
    end
  end

  # implementing eql? and hash so that when an HostName is stored
  # in a hash it has the same hashing properties as the underlying value
  def eql?(value)
    @value.eql?(value.is_a?(HostName) ? value.value : value)
  end

  def hash
    @value.hash
  end
end

class Puppet::Parser::AST::Regex < Puppet::Parser::AST::Leaf
  def initialize(hash)
    super
    # transform value from hash options unless it is already a regular expression
    @value = Regexp.new(@value) unless @value.is_a?(Regexp)
  end

  # we're returning self here to wrap the regexp and to be used in places
  # where a string would have been used, without modifying any client code.
  # For instance, in many places we have the following code snippet:
  #  val = @val.safeevaluate(@scope)
  #  if val.match(otherval)
  #      ...
  #  end
  # this way, we don't have to modify this test specifically for handling
  # regexes.
  #
  def evaluate(scope)
    self
  end

  def match(value)
    @value.match(value)
  end

  def to_s
    Puppet::Pops::Types::PRegexpType.regexp_to_s_with_delimiters(@value)
  end
end
