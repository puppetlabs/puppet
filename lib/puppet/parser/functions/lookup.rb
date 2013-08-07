Puppet::Parser::Functions.newfunction(:lookup, :type => :rvalue, :arity => -2, :doc => <<-'ENDHEREDOC') do |args|
Looks up data defined using Puppet Bindings.
The function is callable with one or two arguments and optionally with a lambda to process the result.
The second argument can be a type specification; a String that describes the type of the produced result.
If a value is found, an assert is made that the value is compliant with the specified type.

When called with one argument; the name:

    lookup('the_name')

When called with two arguments; the name, and the expected type:

    lookup('the_name', 'String')

Using a lambda to process the looked up result.

    lookup('the_name') |$result| { if $result == undef { 'Jane Doe' } else { $result }}

The type specification is one of:

* the basic types; 'Integer', 'String', 'Float', 'Boolean', or 'Pattern' (regular expression)
* an Array with an optional element type given in '[]', that when not given defaults to '[Data]'
* a Hash with optional key and value types given in '[]', where key type defaults to 'Literal' and value to 'Data', if
  only one type is given, the key defaults to 'Literal'
* the abstract type 'Literal' which is one of the basic types
* the abstract type 'Data' which is 'Literal', or type compatible with Array[Data], or Hash[Literal, Data]
* the abstract type 'Collection' which is Array or Hash of any element type.
* the abstract type 'Object' which is any kind of type

ENDHEREDOC

  unless Puppet[:binder] || Puppet[:parser] == 'future'
    raise Puppet::ParseError, "The lookup function is only available with settings --binder true, or --parser future" 
  end
  type_parser = Puppet::Pops::Types::TypeParser.new
  pblock    = args[-1] if args[-1].is_a?(Puppet::Parser::AST::Lambda)
  type_name = args[1] unless args[1].is_a?(Puppet::Parser::AST::Lambda)
  type = type_parser.parse( type_name || "Data")
  result = compiler.injector.lookup(self, type, args[0])
  if pblock
    result = pblock.call(self, result.nil? ? :undef : result)
  end
  result.nil? ? :undef : result
end
