# Evaluates an Embedded Puppet (EPP) template string and returns the rendered
# text result as a String.
#
# `inline_epp('<EPP TEMPLATE STRING>', <PARAMETER HASH>)`
#
# The first argument to this function should be a string containing an EPP
# template. In most cases, the last argument is optional; if used, it should be a
# [hash](/puppet/latest/reference/lang_data_hash.html) that contains parameters to
# pass to the template.
#
# - See the [template](/puppet/latest/reference/lang_template.html) documentation
# for general template usage information.
# - See the [EPP syntax](/puppet/latest/reference/lang_template_epp.html)
# documentation for examples of EPP.
#
# For example, to evaluate an inline EPP template and pass it the `docroot` and
# `virtual_docroot` parameters, call the `inline_epp` function like this:
#
# `inline_epp('docroot: <%= $docroot %> Virtual docroot: <%= $virtual_docroot %>',
# { 'docroot' => '/var/www/html', 'virtual_docroot' => '/var/www/example' })`
#
# Puppet produces a syntax error if you pass more parameters than are declared in
# the template's parameter tag. When passing parameters to a template that
# contains a parameter tag, use the same names as the tag's declared parameters.
#
# Parameters are required only if they are declared in the called template's
# parameter tag without default values. Puppet produces an error if the
# `inline_epp` function fails to pass any required parameter.
#
# An inline EPP template should be written as a single-quoted string or
# [heredoc](/puppet/latest/reference/lang_data_string.html#heredocs).
# A double-quoted string is subject to expression interpolation before the string
# is parsed as an EPP template.
#
# For example, to evaluate an inline EPP template using a heredoc, call the
# `inline_epp` function like this:
#
# ~~~ puppet
# # Outputs 'Hello given argument planet!'
# inline_epp(@(END), { x => 'given argument' })
# <%- | $x, $y = planet | -%>
# Hello <%= $x %> <%= $y %>!
# END
# ~~~
#
# @since 4.0.0
#
Puppet::Functions.create_function(:inline_epp, Puppet::Functions::InternalFunction) do

  dispatch :inline_epp do
    scope_param()
    param 'String', :template
    optional_param 'Hash[Pattern[/^\w+$/], Any]', :parameters
  end

  def inline_epp(scope, template, parameters = nil)
    Puppet::Pops::Evaluator::EppEvaluator.inline_epp(scope, template, parameters)
  end
end
