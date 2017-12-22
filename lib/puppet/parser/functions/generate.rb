# Runs an external command and returns the results
Puppet::Parser::Functions::newfunction(:generate, :arity => -2, :type => :rvalue,
    :doc => "Calls an external command on the Puppet master and returns
    the results of the command.  Any arguments are passed to the external command as
    arguments.  If the generator does not exit with return code of 0,
    the generator is considered to have failed and a parse error is
    thrown.  Generators can only have file separators, alphanumerics, dashes,
    and periods in them.  This function will attempt to protect you from
    malicious generator calls (e.g., those with '..' in them), but it can
    never be entirely safe.  No subshell is used to execute
    generators, so all shell metacharacters are passed directly to
    the generator.") do |args|

      #TRANSLATORS "fully qualified" refers to a fully qualified file system path
      raise Puppet::ParseError, _("Generators must be fully qualified") unless Puppet::Util.absolute_path?(args[0])

      if Puppet.features.microsoft_windows?
        valid = args[0] =~ /^[a-z]:(?:[\/\\][-.~\w]+)+$/i
      else
        valid = args[0] =~ /^[-\/\w.+]+$/
      end

      unless valid
        raise Puppet::ParseError, _("Generators can only contain alphanumerics, file separators, and dashes")
      end

      if args[0] =~ /\.\./
        raise Puppet::ParseError, _("Can not use generators with '..' in them.")
      end

      begin
        Dir.chdir(File.dirname(args[0])) { Puppet::Util::Execution.execute(args).to_str }
      rescue Puppet::ExecutionFailure => detail
        raise Puppet::ParseError, _("Failed to execute generator %{generator}: %{detail}") % { generator: args[0], detail: detail }, detail.backtrace
      end
end
