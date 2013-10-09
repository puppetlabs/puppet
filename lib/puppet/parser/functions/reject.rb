require 'puppet/parser/ast/lambda'

Puppet::Parser::Functions::newfunction(
:reject,
:type => :rvalue,
:arity => 2,
:doc => <<-'ENDHEREDOC') do |args|
  Applies a parameterized block or regular expression to each element in a sequence of entries from the first
  argument and returns an array with the entries for which the block did *not* evaluate to true.

  This function comes in two forms, a simpler variant where a regular expression given in string form
  is used to reject matching entries, and one that takes a parameterized block (lambda).

  The simple form takes two mandatory arguments; the first should be an Array or a Hash, and the
  second a regular expression in String form.

        reject($a, '^sodium.*')

  When the first argument is an array, the regular expression is applied to each element, and when
  the first argument is a Hash it is applied to each key.

  The more advanced form takes two mandatory arguments: the first should be an Array or a Hash, and the second
  a parameterized block as produced by the puppet syntax:

        $a.reject |$x| { ... }

  When the first argument is an Array, the block is called with each entry in turn. When the first argument
  is a hash the entry is an array with `[key, value]`.

  The returned filtered object is of the same type as the receiver.

  *Examples*

        # selects all that does not end with berry
        $a = ["rasberry", "blueberry", "orange"]
        $a.reject |$x| { $x =~ /berry$/ }

  - Since 3.2
  - requires `parser = future` to use the parameterized block form
  ENDHEREDOC

  def reject_lambda(receiver, pblock)
    case receiver
    when Array
      receiver.reject {|x| pblock.call(self, x) }
    when Hash
      ensure_hash(receiver.reject {|x, y| pblock.call(self, [x, y]) })
    else
      raise ArgumentError, ("reject(): wrong argument type (#{receiver.class}; must be an Array or a Hash.")
    end
  end

  def reject_pattern(receiver, pattern)
    case receiver
    when Array
      receiver.reject { |e| e =~ pattern }
    when Hash
      ensure_hash( receiver.reject { |e| e =~ pattern } )
    else
      raise ArgumentError, ("reject(): wrong argument type (#{receiver.class}; must be an Array or a Hash.")
    end
  end

  def ensure_hash(o)
    # Ruby 1.8.7 returns Array in some cases
    o.is_a?(Hash) ? o : Hash[o]
  end

  if args.size != 2
    raise ArgumentError, "reject(): Wrong number of arguments given #{args.size} for 2"
  end

  receiver = args[0]
  predicate = args[1]
  case predicate
  when String
    reject_pattern(receiver, Regexp.new(predicate))
  when Puppet::Parser::AST::Lambda
    reject_lambda(receiver, predicate)
  else
    expected = Puppet[:parser] == 'future' ? 'a parameterized block or a string' : 'a string'
    raise ArgumentError, ("reject(): wrong argument type (#{predicate.class}; must be #{expected}, got '#{predicate.class}'.")
  end
end
