Puppet::Parser::Functions.newfunction(:lookup, :type => :rvalue, :arity => -2) do |args|
  type_parser = Puppet::Pops::Types::TypeParser.new
  type = type_parser.parse(args[1] || "Data")
  compiler.injector.lookup(self, type, args[0])
end
