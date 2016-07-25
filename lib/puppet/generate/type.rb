require 'erb'
require 'fileutils'
require 'puppet/util/autoload'
require 'puppet/generate/models/type/type'

module Puppet
  module Generate
    # Reponsible for generating type definitions in Puppet
    class Type
      # Represents an input to the type generator
      class Input
        # Gets the path to the input.
        attr_reader :path

        # Gets the format to use for generating the output file.
        attr_reader :format

        # Initializes an input.
        # @param base [String] The base path where the input is located.
        # @param path [String] The path to the input file.
        # @param format [Symbol] The format to use for generation.
        # @return [void]
        def initialize(base, path, format)
          @base = base
          @path = path
          self.format = format
        end

        # Gets the expected resource type name for the input.
        # @return [Symbol] Returns the expected resource type name for the input.
        def type_name
          File.basename(@path, '.rb').to_sym
        end

        # Sets the format to use for this input.
        # @param format [Symbol] The format to use for generation.
        # @return [Symbol] Returns the new format.
        def format=(format)
          format = format.to_sym
          raise "unsupported format '#{format}'." unless self.class.supported_format?(format)
          @format = format
        end

        # Determines if the output file is up-to-date with respect to the input file.
        # @return [Boolean] Returns true if the output is up-to-date or false if not.
        def up_to_date?
          Puppet::FileSystem::exist?(output_path) && (Puppet::FileSystem::stat(@path) <=> Puppet::FileSystem::stat(output_path)) <= 0
        end

        # Gets the path to the output file.
        # @return [String] Returns the path to the output file.
        def output_path
          @output_path ||=
            case @format
            when :pcore
              File.join(@base, 'pcore', 'types', "#{File.basename(@path, '.rb')}.pp")
            else
              raise "unsupported format '#{@format}'."
            end
        end

        # Sets the path to the output file.
        # @param path [String] The new path to the output file.
        # @return [String] Returns the new path to the output file.
        def output_path=(path)
          @output_path = path
        end

        # Gets the path to the template to use for this input.
        # @return [String] Returns the path to the template.
        def template_path
          File.join(File.dirname(__FILE__), 'templates', 'type', "#{@format}.erb")
        end

        # Gets the string representation of the input.
        # @return [String] Returns the string representation of the input.
        def to_s
          @path
        end

        # Determines if the given format is supported
        # @param format [Symbol] The format to use for generation.
        # @return [Boolean] Returns true if the format is supported or false if not.
        def self.supported_format?(format)
          [:pcore].include?(format)
        end
      end

      # Finds the inputs for the generator.
      # @param format [Symbol] The format to use.
      # @param environment [Puppet::Node::Environment] The environment to search for inputs. Defaults to the current environment.
      # @return [Array<Input>] Returns the array of inputs.
      def self.find_inputs(format = :pcore, environment = Puppet.lookup(:current_environment))
        Puppet.debug "Searching environment '#{environment.name}' for custom types."

        inputs = []
        environment.modules.each do |mod|
          directory = File.join(Puppet::Util::Autoload.cleanpath(mod.plugin_directory), 'puppet', 'type')
          unless Puppet::FileSystem.exist?(directory)
            Puppet.debug "Skipping '#{mod.name}' module because it contains no custom types."
            next
          end

          Puppet.debug "Searching '#{mod.name}' module for custom types."
          Dir.glob("#{directory}/*.rb") do |file|
            next unless Puppet::FileSystem.file?(file)
            Puppet.debug "Found custom type source file '#{file}'."
            inputs << Input.new(mod.path, file, format)
          end
        end

        # Sort the inputs by path
        inputs.sort_by! { |input| input.path }
      end

      # Generates files for the given inputs.
      # @param inputs [Array<Input>] The inputs to generate files for.
      # @param force [Boolean] True to force the generation of the output files (skip up-to-date checks) or false if not.
      # @return [void]
      def self.generate(inputs, force = false)
        if inputs.empty?
          Puppet.notice 'No custom types were found.'
          return nil
        end

        templates = {}
        templates.default_proc = lambda { |hash, key|
          raise "template was not found at '#{key}'." unless Puppet::FileSystem.file?(key)
          template = ERB.new(File.read(key), nil, '-')
          template.filename = key
          template
        }

        up_to_date = true
        Puppet.notice 'Generating Puppet resource types.'
        inputs.each do |input|
          if !force && input.up_to_date?
            Puppet.debug "Skipping '#{input}' because it is up-to-date."
            next
          end

          up_to_date = false

          type_name = input.type_name
          Puppet.debug "Loading custom type '#{type_name}' in '#{input}'."
          begin
            require input.path
          rescue SystemExit
            raise
          rescue Exception => e
            # Log the exception and move on to the next input
            Puppet.log_exception(e, "Failed to load custom type '#{type_name}' from '#{input}': #{e.message}")
            next
          end

          # HACK: there's no way to get a type without loading it (sigh); for now, just get the types hash directly
          types ||= Puppet::Type.instance_variable_get('@types')

          # Assume the type follows the naming convention
          unless type = types[type_name]
            Puppet.error "Custom type '#{type_name}' was not defined in '#{input}'."
            next
          end

          # Create the model
          begin
            model = Models::Type::Type.new(type)
          rescue Exception => e
            # Move on to the next input
            Puppet.log_exception(e, "#{input}: #{e.message}")
            next
          end

          # Render the template
          begin
            result = model.render(templates[input.template_path])
          rescue Exception => e
            Puppet.log_exception(e)
            raise
          end

          # Write the output file
          begin
            Puppet.notice "Generating '#{input.output_path}' using '#{input.format}' format."
            FileUtils.mkdir_p(File.dirname(input.output_path))
            File.open(input.output_path, 'w') do |file|
              file.write(result)
            end
          rescue Exception => e
            Puppet.log_exception(e, "Failed to generate '#{input.output_path}': #{e.message}")
            # Move on to the next input
            next
          end
        end

        Puppet.notice 'No files were generated because all inputs were up-to-date.' if up_to_date
      end
    end
  end
end
