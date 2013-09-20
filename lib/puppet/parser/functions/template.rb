Puppet::Parser::Functions::newfunction(:template, :type => :rvalue, :arity => -2, :doc =>
  "Evaluate a template and return its value.  See
  [the templating docs](http://docs.puppetlabs.com/guides/templating.html) for
  more information.

  Note that if multiple templates are specified, their output is all
  concatenated and returned as the output of the function.") do |vals|
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
