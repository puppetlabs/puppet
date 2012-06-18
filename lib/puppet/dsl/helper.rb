# Helper for detecting the DSL type
module Puppet
  module DSL
    module Helper

      def use_ruby_dsl?(env)
        dsl_type_for(env) == :ruby
      end

      def use_puppet_dsl?(env)
        dsl_type_for(env) == :puppet
      end

      # dsl type detection is based on file extension
      def dsl_type_for(env)
        type = if Puppet.settings.value(:manifest, env.to_s) =~ /\.rb\z/
                 :ruby
               else
                 :puppet
               end

        # MLEN:FIXME: For testing purposes only, will be removed in future
        Puppet[:dsl] || type
      end

      def ruby_code(env)
        file = Puppet.settings.value :manifest, env.to_s
        code = Puppet.settings.uninterpolated_value :code, env.to_s
        code = File.read file if code == nil or code == ""
        code
      end

    end
  end
end


