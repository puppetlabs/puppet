module Puppet
  module Util
    class CommandLine
      class LegacyCommandLine

        # A placeholder struct for storing a name/run_mode pair
        LegacyApp = Struct.new(:name, :run_mode)
        #class LegacyApp
        #  attr_accessor :name, :run_mode
        #  def initialize(name, run_mode)
        #    @name = name
        #    @run_mode = run_mode
        #  end
        #end

        DefaultRunMode = :user

        LEGACY_APPS = {
            :puppetd => LegacyApp.new(:agent, :agent),
            :puppetca => LegacyApp.new(:cert, :master),
            :puppetdoc => LegacyApp.new(:doc, :master),
            :filebucket => LegacyApp.new(:filebucket, DefaultRunMode),
            :puppet => LegacyApp.new(:apply, DefaultRunMode),
            :pi => LegacyApp.new(:describe, DefaultRunMode),
            :puppetqd => LegacyApp.new(:queue, DefaultRunMode),
            :ralsh => LegacyApp.new(:resource, DefaultRunMode),
            :puppetrun => LegacyApp.new(:kick, DefaultRunMode),
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
end