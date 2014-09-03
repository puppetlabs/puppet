Puppet::Parser::Functions::newfunction(:template, :type => :rvalue, :arity => -2, :doc =>
  "Loads an ERB template from a module, evaluates it, and returns the resulting
  value as a string.

  The argument to this function should be a `<MODULE NAME>/<TEMPLATE FILE>`
  reference, which will load `<TEMPLATE FILE>` from a module's `templates`
  directory. (For example, the reference `apache/vhost.conf.erb` will load the
  file `<MODULES DIRECTORY>/apache/templates/vhost.conf.erb`.)

  This function can also accept:

  * An absolute path, which can load a template file from anywhere on disk.
  * Multiple arguments, which will evaluate all of the specified templates and
  return their outputs concatenated into a single string.") do |vals|
    vals.collect do |file|
      # Use a wrapper, so the template can't get access to the full
      # Scope object.
      debug "Retrieving template #{file}"

      wrapper = Puppet::Parser::TemplateWrapper.new(self)
      wrapper.file = file
      begin
        wrapper.result
      rescue => detail
        info = detail.backtrace.first.split(':')
        raise Puppet::ParseError,
          "Failed to parse template #{file}:\n  Filepath: #{info[0]}\n  Line: #{info[1]}\n  Detail: #{detail}\n"
      end
    end.join("")
end
