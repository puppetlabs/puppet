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
        if Puppet.settings.value(:manifest, env.to_s) =~ /\.rb\z/
          :ruby
        else
          :puppet
        end
      end

      # TODO: document the behaviour:
      # setting manifest to ruby file and setting code to ruby code will
      # execute the code as a ruby DSL
      def ruby_code(env)
        file = Puppet.settings.value :manifest, env.to_s
        code = Puppet.settings.uninterpolated_value :code, env.to_s
        code = File.read file if code == nil or code == ""
        code
      end

    end
  end
end


