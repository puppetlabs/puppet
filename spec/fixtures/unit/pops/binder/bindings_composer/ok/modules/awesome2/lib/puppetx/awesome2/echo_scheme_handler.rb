require 'puppetx/puppet/bindings_scheme_handler'

module Puppetx
  module Awesome2
    # A binding scheme that echos its path
    # 'echo:/quick/brown/fox' becomes key '::quick::brown::fox' => 'echo: quick brown fox'.
    # (silly class for testing loading of extension)
    #
    class EchoSchemeHandler < Puppetx::Puppet::BindingsSchemeHandler
      def contributed_bindings(uri, scope, composer)
        factory = ::Puppet::Pops::Binder::BindingsFactory
        bindings = factory.named_bindings("echo")
        bindings.bind.name(uri.path.gsub(/\//, '::')).to("echo: #{uri.path.gsub(/\//, ' ').strip!}")
        result = factory.contributed_bindings("echo", bindings.model) ### , nil)
      end
    end
  end
end