Puppet::Parser::Functions::newfunction(
    :fail,
    :arity => -1,
    :doc   => <<DOC
Fail with a parse error. Any parameters will be stringified,
concatenated, and passed to the exception-handler.
DOC
) do |vals|
    vals = vals.collect { |s| s.to_s }.join(" ") if vals.is_a? Array
    raise Puppet::ParseError, vals.to_s
end
