module Puppet
  module Acceptance
    module WindowsUtils
      def profile_base(agent)
        getbasedir = <<'END'
require 'win32/dir'
puts Dir::PROFILE.match(/(.*)\\\\[^\\\\]*/)[1]
END
        on(agent, "#{ruby_cmd(agent)} -rubygems -e \"#{getbasedir}\"").stdout.chomp
      end

      # ruby for Windows on a PE install lives in <path to Puppet Enterprise>/sys/ruby/bin/ruby.exe
      # However, FOSS can just use "ruby".
      def ruby_cmd(agent)
        if options[:type] =~ /pe/
          pre_env = agent['puppetbindir'] ? "env PATH=\"#{agent['puppetbindir']}:#{agent['puppetbindir']}/../sys/ruby/bin/:${PATH}\"" : ''
          "#{pre_env} ruby.exe"
        else
          'ruby'
        end
      end

    end
  end
end
