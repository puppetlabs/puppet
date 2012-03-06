module Puppet
  module Util
    class LegacyCommandLine

      # XXX need docs
      class LegacyApp
        attr_accessor :name, :run_mode
        def initialize(name, run_mode)
          @name = name
          @run_mode = run_mode
        end
      end

      # TODO: fix this!!
      # might want to use 'nil' instead of user, because those apps don't explicitly specify their run mode... they just
      # inherit the default of :user
      LEGACY_APPS = {
          :puppetd => LegacyApp.new(:agent, :agent),
          :puppetca => LegacyApp.new(:cert, :master),
          :puppetdoc => LegacyApp.new(:doc, :master),
          :filebucket => LegacyApp.new(:filebucket, :user),
          :puppet => LegacyApp.new(:apply, :user),
          :pi => LegacyApp.new(:describe, :user),
          :puppetqd => LegacyApp.new(:queue, :user),
          :ralsh => LegacyApp.new(:resource, :user),
          :puppetrun => LegacyApp.new(:kick, :user),
          :puppetmasterd => LegacyApp.new(:master, :master),
          :puppetdevice => LegacyApp.new(:device, :agent),
      }

      LEGACY_NAMES = LEGACY_APPS.inject({}) do |result, entry|
        key, app = *entry
        result[app.name] = key
        result
      end

    end
  end
end