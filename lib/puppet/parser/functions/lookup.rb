Puppet::Parser::Functions.newfunction(:lookup, :type => :rvalue) do |args|
  compiler.injector.lookup(self, args[0])
end
