class Hiera
  module Backend
    class Puppet_backend
      def initialize
        Hiera.debug("Hiera Puppet backend starting")
      end

      def hierarchy(scope, override)
        begin
          data_class = Config[:puppet][:datasource] || "data"
        rescue
          data_class = "data"
        end

        calling_class = scope.resource.name.to_s.downcase
        calling_module = calling_class.split("::").first

        hierarchy = Config[:hierarchy] || [calling_class, calling_module]

        hierarchy = [hierarchy].flatten.map do |klass|
          klass = Backend.parse_string(klass, scope,
            {
              "calling_class"  => calling_class,
              "calling_module" => calling_module
            }
          )

          next if klass == ""

          [data_class, klass].join("::")
        end.compact

        hierarchy << [calling_class, data_class].join("::")

        unless calling_module == calling_class
          hierarchy << [calling_module, data_class].join("::")
        end

        hierarchy.insert(0, [data_class, override].join("::")) if override

        hierarchy
      end

      def lookup(key, scope, order_override, resolution_type)
        answer = nil

        Hiera.debug("Looking up #{key} in Puppet backend")

        include_class = Puppet::Parser::Functions.function(:include)
        loaded_classes = scope.catalog.classes

        hierarchy(scope, order_override).each do |klass|
          Hiera.debug("Looking for data in #{klass}")

          varname = [klass, key].join("::")
          temp_answer = nil

          unless loaded_classes.include?(klass)
            begin
              if scope.respond_to?(:function_include)
                scope.function_include(klass)
              else
                scope.real.function_include(klass)
              end

              temp_answer = scope[varname]
              Hiera.debug("Found data in class #{klass}")
            rescue
            end
          else
            temp_answer = scope[varname]
          end

          next if temp_answer == :undefined

          if temp_answer
            # For array resolution we just append to the array whatever we
            # find, we then go onto the next file and keep adding to the array.
            #
            # For priority searches we break after the first found data item.
            case resolution_type
            when :array
              answer ||= []
              answer << Backend.parse_answer(temp_answer, scope)
            when :hash
              answer ||= {}
              answer = Backend.parse_answer(temp_answer, scope).merge answer
            else
              answer = Backend.parse_answer(temp_answer, scope)
              break
            end
          end
        end

        answer = nil if answer == :undefined

        answer
      end
    end
  end
end

