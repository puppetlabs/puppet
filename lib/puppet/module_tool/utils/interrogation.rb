module Puppet::Module::Tool
  module Utils

    # = Interrogation
    #
    # This module contains methods to emit questions to the console.
    module Interrogation
      def confirms?(question)
        $stderr.print "#{question} [y/N]: "
        $stdin.gets =~ /y/i
      end

      def prompt(question, quiet = false)
        $stderr.print "#{question}: "
        system 'stty -echo' if quiet
        $stdin.gets.strip
      ensure
        if quiet
          system 'stty echo'
          say "\n---------"
        end
      end
    end
  end
end
