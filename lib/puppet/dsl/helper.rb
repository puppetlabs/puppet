module Puppet
  module DSL
    ##
    # Module that gathers helper functions for Ruby DSL.
    ##
    module Helper

      ##
      # Tests whether to use ruby dsl.
      ##
      def use_ruby_dsl?(env)
        dsl_type_for(env).equal? :ruby
      end

      ##
      # Tests whether to use puppet dsl.
      ##
      def use_puppet_dsl?(env)
        dsl_type_for(env).equal? :puppet
      end

      ##
      # Returns the DSL type for the current environments.
      # DSL type is determined by Puppet setting +:manifest+.
      # When the name of manifest ends with ".rb", then the file is interpreted
      # as a Ruby manifest.
      #
      # Return values:
      #   :ruby - when the manifest filename ends with ".rb",
      #   :puppet - otherwise.
      ##
      def dsl_type_for(env)
        if Puppet.settings.value(:manifest, env.to_s) =~ /\.rb\z/
          :ruby
        else
          :puppet
        end
      end

      ##
      # Methods loads code from Ruby manifests.
      # It returns a string with the code.
      # Raises RuntimeError if called when puppet DSL should be used instead.
      #
      # To load code from manifest, set :manifest setting to point at a file
      # with the code.
      #
      # To load the code from Puppet setting :code, assign the code to :code
      # setting and set :manifest setting to a string ending with ".rb".
      # This behaviour is used for testing purposes.
      ##
      def get_ruby_code(env)
        raise "Called when not using Ruby DSL" unless use_ruby_dsl? env
        file = Puppet.settings.value :manifest, env.to_s
        code = Puppet.settings.uninterpolated_value :code, env.to_s
        code = File.read file if code == nil or code == ""
        code
      end

    end
  end
end


