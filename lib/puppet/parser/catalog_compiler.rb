require 'puppet/loaders'
require 'puppet/pops'

# A Catalog "compiler" that is like the regular compiler but with an API
# that is harmonized with the ScriptCompiler
#
# The Script compiler is "one shot" - it does not support rechecking if underlying source has changed or
# deal with possible errors in a cached environment.
#
class Puppet::Parser::CatalogCompiler < Puppet::Parser::Compiler

  # Evaluates the configured setup for a script + code in an environment with modules
  #
  def compile
    Puppet[:strict_variables] = true
    Puppet[:strict] = :error
    Puppet[:rich_data] = true

    super

  rescue Puppet::ParseErrorWithIssue => detail
    detail.node = node.name
    Puppet.log_exception(detail)
    raise
  rescue => detail
    message = "#{detail} on node #{node.name}"
    Puppet.log_exception(detail, message)
    raise Puppet::Error, message, detail.backtrace
  end

end
