Puppet::Parser::Functions::newfunction(:inline_epptemplate, :type => :rvalue, :arity => -2, :doc =>
"Evaluates one or more Embedded Puppet Template (EPP) strings and returns their concatenated result.

EPP support the following tags:
* `<%= puppet expression %>` - This tag renders the value of the expression it contains.
* `<% puppet expression(s) %>` - This tag will execute the expression(s) it contains, but renders nothing.
* `<%# comment %>` - The tag and its content renders nothing.
* `<%%` or `%%>` - Renders a literal `<%` or `%>` respectively.
* `<%-` - Same as `<%` but suppresses any leading whitespace.
* `-%>` - Same as `%>` but suppresses any trailing whitespace on the same line (including line break).

EPP supports parameters by placing an optional parameter list as the very first element in the Epp. As an example,
`<%- ($x, $y, $z='unicorn') -%>` when placed first in the EPP text declares that the parameters `x` and `y` must be
given as template arguments when calling `inline_epptemplate`, and that `z` if not given as a template argument
defaults to `'unicorn'`. Template parameters are available as variables, e.g.arguments `$x`, `$y` and `$z` in the example.

Arguments are passed to the template by calling `inline_epptemplate` with a Hash as the last argument, where parameters
are bound to values, e.g. `inline_epptemplate('...', {'x'=>10, 'y'=>20})`. Excess arguments may be given
(i.e. undeclared parameters). Template parameters shadow variables in outer scopes. Template arguments may be
passed to any template; the template text does not have to have a declaration of parameters.

Several strings may be given as arguments to `inline_epptemplate`, the result is the concatenation of each produced result.
If template arguments are given, they are used for each given template string.

Note: An inline template is best stated using a single-quoted string, or a heredoc since a double-quoted string
is subject to expression interpolation before the string is parsed as an EPP template. Here is an example
using heredoc.

    inline_epptemplate(@(END:epp), {'x'=>'epp template world'})
    <%- ($x) -%>
    Hello <%= $x %>!
    END

") do |arguments|
  # accepts one or more arguments (each being a epp source string), except an optional last argument being a hash
  # of parameters to pass to each evaluation.

  if(arguments[-1].is_a? Hash)
    template_args = arguments[-1]
    arguments = arguments[0..-2]
  else
    template_args = {}
  end
  require 'puppet/parser/parser_factory'
  require 'puppet/parser/ast'

  arguments.collect do |text|
    if text.is_a?(Hash)
      raise IllegalArgumentException, "A Hash may be given as the last argument only"
    end

    parser = Puppet::Parser::ParserFactory.epp_parser(self.compiler.environment)
    parser.string = text
    result = parser.parse()
    raise Puppet::ParseError, "Parsing epp string did not produce an instance of Epp. Got: #{result.class}" unless result.is_a?(Puppet::Parser::AST::Epp)
    result.call(self, template_args)
  end.join("")
end
