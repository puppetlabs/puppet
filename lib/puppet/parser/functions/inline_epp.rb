Puppet::Parser::Functions::newfunction(:inline_epp, :type => :rvalue, :arity => -2, :doc =>
"Evaluates an Embedded Puppet Template (EPP) string and returns the rendered text result as a String.

EPP support the following tags:

* `<%= puppet expression %>` - This tag renders the value of the expression it contains.
* `<% puppet expression(s) %>` - This tag will execute the expression(s) it contains, but renders nothing.
* `<%# comment %>` - The tag and its content renders nothing.
* `<%%` or `%%>` - Renders a literal `<%` or `%>` respectively.
* `<%-` - Same as `<%` but suppresses any leading whitespace.
* `-%>` - Same as `%>` but suppresses any trailing whitespace on the same line (including line break).
* `<%- |parameters| -%>` - When placed as the first tag declares the template's parameters.

Inline EPP supports the following visibilities of variables in scope which depends on how EPP parameters
are used - see further below:

* Global scope (i.e. top + node scopes) - global scope is always visible
* Global + Enclosing scope - if the EPP template does not declare parameters, and no arguments are given
* Global + all given arguments - if the EPP template does not declare parameters, and arguments are given
* Global + declared parameters - if the EPP declares parameters, given argument names must match

EPP supports parameters by placing an optional parameter list as the very first element in the EPP. As an example,
`<%- |$x, $y, $z='unicorn'| -%>` when placed first in the EPP text declares that the parameters `x` and `y` must be
given as template arguments when calling `inline_epp`, and that `z` if not given as a template argument
defaults to `'unicorn'`. Template parameters are available as variables, e.g.arguments `$x`, `$y` and `$z` in the example.
Note that `<%-` must be used or any leading whitespace will be interpreted as text

Arguments are passed to the template by calling `inline_epp` with a Hash as the last argument, where parameters
are bound to values, e.g. `inline_epp('...', {'x'=>10, 'y'=>20})`. Excess arguments may be given
(i.e. undeclared parameters) only if the EPP templates does not declare any parameters at all.
Template parameters shadow variables in outer scopes.

Note: An inline template is best stated using a single-quoted string, or a heredoc since a double-quoted string
is subject to expression interpolation before the string is parsed as an EPP template. Here are examples
(using heredoc to define the EPP text):

    # produces 'Hello local variable world!'
    $x ='local variable'
    inline_epptemplate(@(END:epp))
    <%- |$x| -%>
    Hello <%= $x %> world!
    END

    # produces 'Hello given argument world!'
    $x ='local variable world'
    inline_epptemplate(@(END:epp), { x =>'given argument'})
    <%- |$x| -%>
    Hello <%= $x %> world!
    END

    # produces 'Hello given argument world!'
    $x ='local variable world'
    inline_epptemplate(@(END:epp), { x =>'given argument'})
    <%- |$x| -%>
    Hello <%= $x %>!
    END

    # results in error, missing value for y
    $x ='local variable world'
    inline_epptemplate(@(END:epp), { x =>'given argument'})
    <%- |$x, $y| -%>
    Hello <%= $x %>!
    END

    # Produces 'Hello given argument planet'
    $x ='local variable world'
    inline_epptemplate(@(END:epp), { x =>'given argument'})
    <%- |$x, $y=planet| -%>
    Hello <%= $x %> <%= $y %>!
    END

- Since 3.5
- Requires Future Parser") do |arguments|

  function_fail(["inline_epp() is only available when parser/evaluator future is in effect"])
end
