# Provides feature definitions.
module Puppet::Util::ProviderFeatures
    class ProviderFeature
        require 'puppet/util/methodhelper'
        require 'puppet/util'
        include Puppet::Util
        include Puppet::Util::MethodHelper
        attr_accessor :name, :docs, :methods
        def initialize(name, docs, hash)
            self.name = symbolize(name)
            self.docs = docs
            hash = symbolize_options(hash)
            set_options(hash)
        end
    end

    # Define one or more features.  At a minimum, features require a name
    # and docs, and at this point they should also specify a list of methods
    # required to determine if the feature is present.
    def feature(name, docs, hash)
        @features ||= {}
        if @features.include?(name)
            raise Puppet::DevError, "Feature %s is already defined" % name
        end
        begin
            obj = ProviderFeature.new(name, docs, hash)
            @features[obj.name] = obj
        rescue ArgumentError => detail
            error = ArgumentError.new(
                "Could not create feature %s: %s" % [name, detail]
            )
            error.set_backtrace(detail.backtrace)
            raise error
        end
    end

    # Return a hash of all feature documentation.
    def featuredocs
        str = ""
        @features ||= {}
        return nil if @features.empty?
        names = @features.keys.sort { |a,b| a.to_s <=> b.to_s }
        names.each do |name|
            doc = @features[name].docs.gsub(/\n\s+/, " ")
            str += " - **%s**: %s\n" % [name, doc]
        end
        if providers.length > 0
            str += "<table><tr><th></th>\n"
            names.each do |name|
                str += "<th>%s</th>" % name
            end
            str += "</tr>\n"
            providers.each do |provname|
                prov = provider(provname)
                str += "<tr><td>%s</td>" % provname
                names.each do |feature|
                    have = ""
                    if prov.feature?(feature)
                        have = "<strong>X</strong>"
                    end
                    str += "<td>%s</td>" % have
                end
                str += "</tr>\n"
            end
            str += "</table>\n"
        end
        str
    end

    # Generate a module that sets up the boolean methods to test for given
    # features.
    def feature_module
        unless defined? @feature_module
            @features ||= {}
            @feature_module = ::Module.new
            const_set("FeatureModule", @feature_module)
            features = @features
            # Create a feature? method that can be passed a feature name and
            # determine if the feature is present.
            @feature_module.send(:define_method, :feature?) do |name|
                method = name.to_s + "?"
                if respond_to?(method) and send(method)
                    return true
                else
                    return false
                end
            end

            # Create a method that will list all functional features.
            @feature_module.send(:define_method, :features) do
                return false unless defined?(features)
                features.keys.find_all { |n| feature?(n) }.sort { |a,b| 
                    a.to_s <=> b.to_s 
                }
            end

            # Create a boolean method for each feature so you can test them
            # individually as you might need.
            @features.each do |name, feature|
                method = name.to_s + "?"
                @feature_module.send(:define_method, method) do
                    set = nil
                    feature.methods.each do |m|
                        if is_a?(Class)
                            unless public_method_defined?(m)
                                set = false
                                break
                            end
                        else
                            unless respond_to?(m)
                                set = false
                                break
                            end
                        end
                    end

                    if set.nil?
                        true
                    else
                        false
                    end
                end
            end
        end
        @feature_module
    end
end

# $Id$
