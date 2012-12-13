class Hiera
  module Backend
    class Module_data_backend
      def initialize(cache=nil)
        require 'yaml'

        Hiera.debug("Hiera Module Data backend starting")

        if cache
          @cache = cache
        else
          begin
            require 'hiera/filecache'
            @cache = cache || Filecache.new
          rescue LoadError
            @cache = nil
          end
        end
      end

      def load_module_config(module_name, environment)
        default_config = {:hierarchy => ["common"]}

        if mod = Puppet::Module.find(module_name, environment)
          path = mod.path
          module_config = File.join(path, "data", "hiera.yaml")
          config = nil

          if File.exist?(module_config)
		        begin
              Hiera.debug("Reading config from %s file" % module_config)
              config = load_data(module_config)
            rescue => e
              Hiera.warn("Failed to parse config file %s: %s: %s" % [module_config, e.class, e.to_s])
            end
          end

          config = {} unless config.is_a?(Hash)

          config["path"] = path

          return default_config.merge(config)
        else
          return default_config
        end
      end

      def load_data(path)
        return {} unless File.exist?(path)

        Hiera.debug("Looking for data in source %s" % path)

        if @cache
          @cache.read(path, Hash, {}) do |data|
            YAML.load(data)
          end
        else
          data = YAML.load_file(path)
          unless data.is_a?(Hash)
            data = {}
          end

          data
        end
      end

      def lookup(key, scope, order_override, resolution_type)
        answer = nil

        Hiera.debug("Looking up #{key} in Module Data backend")

        unless scope["module_name"]
          Hiera.debug("Skipping Module Data backend as this does not look like a module")
          return answer
        end

        config = load_module_config(scope["module_name"], scope["environment"])

        unless config["path"]
          Hiera.debug("Could not find a path to the module '%s' in environment '%s'" % [scope["module_name"], scope["environment"]])
          return answer
        end

        config[:hierarchy].each do |source|
          source = File.join(config["path"], "data", "%s.yaml" % Backend.parse_string(source, scope))

          data = load_data(source)

          next if data.empty?
          next unless data.include?(key)

          found = data[key]

          case resolution_type
            when :array
              raise("Hiera type mismatch: expected Array or String and got %s" % found.class) unless [Array, String].include?(found.class)
              answer ||= []
              answer << Backend.parse_answer(found, scope)

            when :hash
              raise("Hiera type mismatch: expected Hash and got %s" % found.class) unless found.is_a?(Hash)
              answer ||= {}
              answer = found.merge(answer)

            else
              answer = Backend.parse_answer(found, scope)
              break
          end
        end

        return answer
      end
    end
  end
end
