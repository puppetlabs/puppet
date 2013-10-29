#--------------------
# A script to retrieve hosts from ldap and create an importable
# cfservd file from them

require 'digest/md5'
#require 'ldap'
require 'puppet/external/nagios/parser.rb'
require 'puppet/external/nagios/base.rb'

module Nagios
  NAGIOSVERSION = '1.1'
  # yay colors
  PINK = "[0;31m"
  GREEN = "[0;32m"
  YELLOW = "[0;33m"
  SLATE = "[0;34m"
  ORANGE = "[0;35m"
  BLUE = "[0;36m"
  NOCOLOR = "[0m"
  RESET = "[0m"

  def self.version
    NAGIOSVERSION
  end

  class Config
    def Config.import(config)

      text = String.new

      File.open(config) { |file|
        file.each { |line|
          text += line
        }
      }
      parser = Nagios::Parser.new
      parser.parse(text)
    end

    def Config.each
      Nagios::Object.objects.each { |object|
        yield object
      }
    end
  end
end
