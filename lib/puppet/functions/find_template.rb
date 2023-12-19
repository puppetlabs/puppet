# frozen_string_literal: true

# Finds an existing template from a module and returns its path.
#
# This function accepts an argument that is a String as a `<MODULE NAME>/<TEMPLATE>`
# reference, which searches for `<TEMPLATE>` relative to a module's `templates`
# directory on the primary server. (For example, the reference `mymod/secret.conf.epp`
# will search for the file `<MODULES DIRECTORY>/mymod/templates/secret.conf.epp`.)
#
# The primary use case is for agent-side template rendering with late-bound variables
# resolved, such as from secret stores inaccessible to the primary server, such as
#
# ```
# $variables = {
#   'password' => Deferred('vault_lookup::lookup',
#                   ['secret/mymod', 'https://vault.example.com:8200']),
# }
#
# # compile the template source into the catalog
# file { '/etc/secrets.conf':
#   ensure  => file,
#   content => Deferred('inline_epp',
#                [find_template('mymod/secret.conf.epp').file, $variables]),
# }
# ```
#
#
#
# This function can also accept:
#
# * An absolute String path, which checks for the existence of a template from anywhere on disk.
# * Multiple String arguments, which returns the path of the **first** template
#   found, skipping nonexistent files.
# * An array of string paths, which returns the path of the **first** template
#   found from the given paths in the array, skipping nonexistent files.
#
# The function returns `undef` if none of the given paths were found.
#
# @since 6.x
#
Puppet::Functions.create_function(:find_template, Puppet::Functions::InternalFunction) do
  dispatch :find_template do
    scope_param
    repeated_param 'String', :paths
  end

  dispatch :find_template_array do
    scope_param
    repeated_param 'Array[String]', :paths_array
  end

  def find_template_array(scope, array)
    find_template(scope, *array)
  end

  def find_template(scope, *args)
    args.each do |file|
      found = Puppet::Parser::Files.find_template(file, scope.compiler.environment)
      if found && Puppet::FileSystem.exist?(found)
        return found
      end
    end
    nil
  end
end
