module Puppet
  module Util
    module Platform
      def windows?
        # Ruby only sets File::ALT_SEPARATOR on Windows and the Ruby standard
        # library uses that to test what platform it's on. In some places we
        # would use Puppet.features.microsoft_windows?, but this method can be
        # used to determine the behavior of the underlying system without
        # requiring features to be initialized and without side effect.
        !!File::ALT_SEPARATOR
      end
      module_function :windows?
    end
  end
end
