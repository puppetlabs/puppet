module Puppet
  module Util
    # would prefer for this namespace to just be called "CommandLine" since we're already inside of a namespace called
    #  'utils', but there is already a class by that name.
    module CommandLineUtils

      class PuppetOptionError < Puppet::Error
      end

      class PuppetUnrecognizedOptionError < PuppetOptionError
      end

      # TODO cprice: document; this is just an abstraction, which would hopefully allow a better implementation later


      #require "puppet/util/command_line_utils/option_parsers/stdlib_parser"
      #PuppetOptionParser = RubyStdLibPuppetOptionParser

      require "puppet/util/command_line_utils/option_parsers/trollop_parser"
      PuppetOptionParser = TrollopPuppetOptionParser

    end
  end
end