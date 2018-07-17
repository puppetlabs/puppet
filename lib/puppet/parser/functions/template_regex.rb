Puppet::Parser::Functions::newfunction(:template_regex, :type => :rvalue, :arity => -2, :doc =>
  "Loads an ERB template from a module, evaluates it, performs a regex replace
  over the evaluated template and returns the resulting value as a string.
  The arguments to this function should be a regex pattern to match (For
  example `^foo`), a replacement string (For example `bar`) and a
  `<MODULE NAME>/<TEMPLATE FILE>` reference, which will load `<TEMPLATE FILE>`
  from a module's `templates` directory. (For example, the reference
  `apache/vhost.conf.erb` will load the file `<MODULES DIRECTORY>/apache/
  templates/vhost.conf.erb`.) This function can also accept:
  * An absolute path, which can load a template file from anywhere on disk.
  * Multiple arguments, which will evaluate all of the specified templates and
  return their outputs concatenated into a single string.") do |args|
    if Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::FEATURE_NOT_SUPPORTED_WHEN_SCRIPTING,
        {:feature => 'ERB template'})
    end
    raise ArgumentError, (_("template_regex(): wrong number of arguments (%{count}; must be greater than two)") % { count: args.length }) if args.length < 3
    regex = String(args[0])
    replace = String(args[1])
    args[2..-1].collect do |file|
      # Use a wrapper, so the template can't get access to the full
      # Scope object.
      debug "Retrieving template #{file}"
      wrapper = Puppet::Parser::TemplateWrapper.new(self)
      wrapper.file = file
      begin
        wrapper.result.gsub(/#{regex}/, replace)
      rescue => detail
        info = detail.backtrace.first.split(':')
        message = []
        message << _("Failed to parse template %{file}:") % { file: file }
        message << _("  Filepath: %{file_path}") % { file_path: info[0] }
        message << _("  Line: %{line}") % { line: info[1] }
        message << _("  Detail: %{detail}") % { detail: detail }
        raise Puppet::ParseError, message.join("\n") + "\n"
      end
    end.join("")
end
