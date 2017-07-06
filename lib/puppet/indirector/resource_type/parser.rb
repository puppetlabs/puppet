require 'puppet/resource/type'
require 'puppet/indirector/code'
require 'puppet/indirector/resource_type'

# The main terminus for Puppet::Resource::Type
#
# This exposes the known resource types from within Puppet. Only find
# and search are supported. When a request is received, Puppet will
# attempt to load all resource types (by parsing manifests and modules) and
# returns a description of the resource types found. The format of these
# objects is documented at {Puppet::Resource::Type}.
#
# @api public
class Puppet::Indirector::ResourceType::Parser < Puppet::Indirector::Code
  desc "Return the data-form of a resource type."

  # Find will return the first resource_type with the given name. It is
  # not possible to specify the kind of the resource type.
  #
  # @param request [Puppet::Indirector::Request] The request object.
  #   The only parameters used from the request are `environment` and
  #   `key`, which corresponds to the resource type's `name` field.
  # @return [Puppet::Resource::Type, nil]
  # @api public
  def find(request)
    Puppet.override(:squelch_parse_errors => true) do
      krt = resource_types_in(request.environment)

      # This is a bit ugly.
      [:hostclass, :definition, :application, :node].each do |type|
        # We have to us 'find_<type>' here because it will
        # load any missing types from disk, whereas the plain
        # '<type>' method only returns from memory.
        if r = krt.send("find_#{type}", request.key)
          return r
        end
      end
      nil
    end
  end

  # Search for resource types using a regular expression. Unlike `find`, this
  # allows you to filter the results by the "kind" of the resource type
  # ("class", "defined_type", or "node"). All three are searched if no
  # `kind` filter is given. This also accepts the special string "`*`"
  # to return all resource type objects.
  #
  # @param request [Puppet::Indirector::Request] The request object. The
  #   `key` field holds the regular expression used to search, and
  #   `options[:kind]` holds the kind query parameter to filter the
  #   result as described above. The `environment` field specifies the
  #   environment used to load resources.
  #
  # @return [Array<Puppet::Resource::Type>, nil]
  #
  # @api public
  def search(request)
    Puppet.override(:squelch_parse_errors => true) do

      krt = resource_types_in(request.environment)
      # Make sure we've got all of the types loaded.
      krt.loader.import_all

      result_candidates = case request.options[:kind]
          when "class"
            krt.hostclasses.values
          when "defined_type"
            krt.definitions.values
          when "application"
            krt.applications.values
          when "node"
            krt.nodes.values
          when nil
            result_candidates = [krt.hostclasses.values, krt.definitions.values, krt.applications.values, krt.nodes.values]
          else
            raise ArgumentError, "Unrecognized kind filter: " +
                      "'#{request.options[:kind]}', expected one " +
                      " of 'class', 'defined_type', 'application', or 'node'."
        end

      result = result_candidates.flatten.reject { |t| t.name == "" }
      return nil if result.empty?
      return result if request.key == "*"

      # Strip the regex of any wrapping slashes that might exist
      key = request.key.sub(/^\//, '').sub(/\/$/, '')
      begin
        regex = Regexp.new(key)
      rescue => detail
        raise ArgumentError, "Invalid regex '#{request.key}': #{detail}", detail.backtrace
      end

      result.reject! { |t| t.name.to_s !~ regex }
      return nil if result.empty?
      result
    end
  end

  def resource_types_in(environment)
    environment.check_for_reparse
    environment.known_resource_types
  end

  def allow_remote_requests?
    Puppet.deprecation_warning("The resource_type endpoint is deprecated in favor of the environment_classes endpoint. See https://docs.puppet.com/puppetserver/latest/puppet-api/v3/environment_classes.html")
    super
  end
end
