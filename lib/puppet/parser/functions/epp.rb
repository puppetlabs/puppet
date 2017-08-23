Puppet::Parser::Functions::newfunction(:epp, :type => :rvalue, :arity => -2, :doc =>
"Evaluates an Embedded Puppet (EPP) template file and returns the rendered text
result as a String.

`epp('<MODULE NAME>/<TEMPLATE FILE>', <PARAMETER HASH>)`

The first argument to this function should be a `<MODULE NAME>/<TEMPLATE FILE>`
reference, which loads `<TEMPLATE FILE>` from `<MODULE NAME>`'s `templates`
directory. In most cases, the last argument is optional; if used, it should be a
[hash](/puppet/latest/reference/lang_data_hash.html) that contains parameters to
pass to the template.

- See the [template](/puppet/latest/reference/lang_template.html) documentation
for general template usage information.
- See the [EPP syntax](/puppet/latest/reference/lang_template_epp.html)
documentation for examples of EPP.

For example, to call the apache module's `templates/vhost/_docroot.epp`
template and pass the `docroot` and `virtual_docroot` parameters, call the `epp`
function like this:

`epp('apache/vhost/_docroot.epp', { 'docroot' => '/var/www/html',
'virtual_docroot' => '/var/www/example' })`

This function can also accept an absolute path, which can load a template file
from anywhere on disk.

Puppet produces a syntax error if you pass more parameters than are declared in
the template's parameter tag. When passing parameters to a template that
contains a parameter tag, use the same names as the tag's declared parameters.

Parameters are required only if they are declared in the called template's
parameter tag without default values. Puppet produces an error if the `epp`
function fails to pass any required parameter.

- Since 4.0.0") do |args|

  Puppet::Parser::Functions::Error.is4x('epp')
end
