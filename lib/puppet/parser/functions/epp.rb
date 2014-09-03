Puppet::Parser::Functions::newfunction(:epp, :type => :rvalue, :arity => -2, :doc =>
"Evaluates an Embedded Puppet Template (EPP) file and returns the rendered text result as a String.

The first argument to this function should be a `<MODULE NAME>/<TEMPLATE FILE>`
reference, which will load `<TEMPLATE FILE>` from a module's `templates`
directory. (For example, the reference `apache/vhost.conf.epp` will load the
file `<MODULES DIRECTORY>/apache/templates/vhost.conf.epp`.)

The second argument is optional; if present, it should be a hash containing parameters for the
template. (See below.)

EPP supports the following tags:

* `<%= puppet expression %>` - This tag renders the value of the expression it contains.
* `<% puppet expression(s) %>` - This tag will execute the expression(s) it contains, but renders nothing.
* `<%# comment %>` - The tag and its content renders nothing.
* `<%%` or `%%>` - Renders a literal `<%` or `%>` respectively.
* `<%-` - Same as `<%` but suppresses any leading whitespace.
* `-%>` - Same as `%>` but suppresses any trailing whitespace on the same line (including line break).
* `<%- |parameters| -%>` - When placed as the first tag declares the template's parameters.

File based EPP supports the following visibilities of variables in scope:

* Global scope (i.e. top + node scopes) - global scope is always visible
* Global + all given arguments - if the EPP template does not declare parameters, and arguments are given
* Global + declared parameters - if the EPP declares parameters, given argument names must match

EPP supports parameters by placing an optional parameter list as the very first element in the EPP. As an example,
`<%- |$x, $y, $z = 'unicorn'| -%>` when placed first in the EPP text declares that the parameters `x` and `y` must be
given as template arguments when calling `inline_epp`, and that `z` if not given as a template argument
defaults to `'unicorn'`. Template parameters are available as variables, e.g.arguments `$x`, `$y` and `$z` in the example.
Note that `<%-` must be used or any leading whitespace will be interpreted as text

Arguments are passed to the template by calling `epp` with a Hash as the last argument, where parameters
are bound to values, e.g. `epp('...', {'x'=>10, 'y'=>20})`. Excess arguments may be given
(i.e. undeclared parameters) only if the EPP templates does not declare any parameters at all.
Template parameters shadow variables in outer scopes. File based epp does never have access to variables in the
scope where the `epp` function is called from.

- See function inline_epp for examples of EPP
- Since 3.5
- Requires Future Parser") do |args|

  function_fail(["epp() is only available when parser/evaluator future is in effect"])
end
