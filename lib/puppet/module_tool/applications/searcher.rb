module Puppet::ModuleTool
  module Applications
    class Searcher < Application
      include Puppet::Forge::Errors

      def initialize(term, forge, options = {})
        @term = term
        @forge = forge
        super(options)
      end

      def run
        results = {}
        begin
          Puppet.notice _("Searching %{host} ...") % { host: @forge.host }
          results[:answers] = @forge.search(@term)
          results[:result] = :success
        rescue ForgeError => e
          results[:result] = :failure
          results[:error] = {
            :oneline   => e.message,
            :multiline => e.multiline,
          }
        end
        results
      end
    end
  end
end
