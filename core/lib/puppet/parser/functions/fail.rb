Puppet::Parser::Functions::newfunction(:fail, :arity => -1, :doc => "Fail with a parse error.") do |vals|
    vals = vals.collect { |s| s.to_s }.join(" ") if vals.is_a? Array
    raise Puppet::ParseError, vals.to_s
end
