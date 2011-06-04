class Hiera
    module Backend
        class Puppet_backend
            def initialize
                Hiera.debug("Hiera Puppet backend starting")
            end

            def hierarchy(scope)
                begin
                    data_class = Config[:puppet][:datasource] || "data"
                rescue
                    data_class = "data"
                end

                calling_class = scope.real.resource.name.to_s.downcase
                calling_module = calling_class.split("::").first

                hierarchy = Config[:hierarchy] || [calling_class, calling_module]

                hierarchy = hierarchy.map do |klass|
                    klass = Backend.parse_string(klass, scope, {"calling_class" => calling_class, "calling_module" => calling_module})

                    [data_class, klass].join("::")
                end

                hierarchy << [calling_class, data_class].join("::")
                hierarchy << [calling_module, data_class].join("::") unless calling_module == calling_class

                hierarchy.insert(0, [data_class, @override].join("::")) if @override

                hierarchy
            end

            def lookup(key, scope, order_override, resolution_type)
                answer = nil

                Hiera.debug("Looking up #{key} in Puppet backend")

                include_class = Puppet::Parser::Functions.function(:include)
                loaded_classes = scope.real.catalog.classes

                hierarchy(scope).each do |klass|
                    unless answer
                        Hiera.debug("Looking for data in #{klass}")

                        varname = [klass, key].join("::")
                        unless loaded_classes.include?(klass)
                            begin
                                scope.real.function_include(klass)
                                answer = scope[varname]
                                Hiera.debug("Found data in class #{klass}")
                            rescue
                            end
                        else
                            answer = scope[varname]
                        end
                    end
                end

                answer
            end
        end
    end
end
