require 'puppet/acceptance/common_utils'

module Puppet
  module Acceptance
    module WindowsUtils
      require 'puppet/acceptance/windows_utils/service.rb'

      def profile_base(agent)
        ruby = Puppet::Acceptance::CommandUtils.ruby_command(agent)
        getbasedir = <<'END'
require 'win32/dir'
puts Dir::PROFILE.match(/(.*)\\\\[^\\\\]*/)[1]
END
        on(agent, "#{ruby} -e \"#{getbasedir}\"").stdout.chomp
      end
    end
  end
end
