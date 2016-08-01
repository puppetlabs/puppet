require 'puppet/face'
require 'puppet/generate/type'

# Create the Generate face
Puppet::Face.define(:generate, '0.1.0') do
  copyright 'Puppet Inc.', 2016
  license   'Apache 2 license; see COPYING'

  summary 'Generates Puppet code from Ruby definitions.'

  action(:types) do
    summary 'Generates Puppet code for custom types'

    description <<-'EOT'
      Generates definitions for custom resource types using Puppet code.

      Types defined in Puppet code can be used to isolate custom type definitions
      between different environments.
    EOT

    examples <<-'EOT'
      Generate Puppet type definitions for all custom resource types in the current environment:

          $ puppet generate types

      Generate Puppet type definitions for all custom resource types in the specified environment:

          $ puppet generate types --environment development
    EOT

    option '--format <format>' do
      summary 'The generation output format to use. Supported formats: pcore.'
      default_to { 'pcore' }

      before_action do |_, _, options|
        raise ArgumentError, "'#{options[:format]}' is not a supported format for type generation." unless ['pcore'].include?(options[:format])
      end
    end

    option '--force' do
      summary 'Forces the generation of output files (skips up-to-date checks).'
      default_to { false }
    end

    when_invoked do |options|
      generator = Puppet::Generate::Type
      inputs = generator.find_inputs(options[:format].to_sym)
      environment = Puppet.lookup(:current_environment)

      # get the common output directory (in <envroot>/.resource_types) - create it if it does not exists
      # error if it exists and is not a directory
      #
      path_to_env = environment.configuration.path_to_env
      outputdir = File.join(path_to_env, '.resource_types')
      if Puppet::FileSystem.exist?(outputdir) && !Puppet::FileSystem.directory?(outputdir)
        raise ArgumentError, "The output directory '#{outputdir}' exists and is not a directory"
      end
      Puppet::FileSystem::mkpath(outputdir)

      generator.generate(inputs, outputdir, options[:force])
      nil
    end
  end
end
