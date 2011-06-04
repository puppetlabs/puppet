class Hiera
    module Puppet_logger
        class << self
            def warn(msg); Puppet.notice("hiera(): #{msg}"); end
            def debug(msg); Puppet.debug("hiera(): #{msg}"); end
        end
    end
end
