require 'hiera/scope'
require_relative 'sub_lookup'
module Puppet::Pops
module Lookup
# Adds support for interpolation expressions. The expressions may contain keys that uses dot-notation
# to further navigate into hashes and arrays
#
# @api public
module Interpolation
  include SubLookup

  # @param value [Object] The value to interpolate
  # @param context [Context] The current lookup context
  # @param allow_methods [Boolean] `true` if interpolation expression that contains lookup methods are allowed
  # @return [Object] the result of resolving all interpolations in the given value
  # @api public
  def interpolate(value, context, allow_methods)
    case value
    when String
      value.index('%{').nil? ? value : interpolate_string(value, context, allow_methods)
    when Array
      value.map { |element| interpolate(element, context, allow_methods) }
    when Hash
      result = {}
      value.each_pair { |k, v| result[interpolate(k, context, allow_methods)] = interpolate(v, context, allow_methods) }
      result
    else
      value
    end
  end

  private

  EMPTY_INTERPOLATIONS = {
    '' => true,
    '::' => true,
    '""' => true,
    "''" => true,
    '"::"' => true,
    "'::'" => true
  }.freeze

  # Matches a key that is quoted using a matching pair of either single or double quotes.
  QUOTED_KEY = /^(?:"([^"]+)"|'([^']+)')$/

  def interpolate_string(subject, context, allow_methods)
    lookup_invocation = context.is_a?(Invocation) ? context : context.invocation
    lookup_invocation.with(:interpolate, subject) do
      subject.gsub(/%\{([^\}]*)\}/) do |match|
        expr = $1
        # Leading and trailing spaces inside an interpolation expression are insignificant
        expr.strip!
        value = nil
        unless EMPTY_INTERPOLATIONS[expr]
          method_key, key = get_method_and_data(expr, allow_methods)
          is_alias = method_key == :alias

          # Alias is only permitted if the entire string is equal to the interpolate expression
          fail(Issues::HIERA_INTERPOLATION_ALIAS_NOT_ENTIRE_STRING) if is_alias && subject != match
          value = interpolate_method(method_key).call(key, lookup_invocation, subject)

          # break gsub and return value immediately if this was an alias substitution. The value might be something other than a String
          return value if is_alias

          value = lookup_invocation.check(method_key == :scope ? "scope:#{key}" : key) { interpolate(value, lookup_invocation, allow_methods) }
        end
        value.nil? ? '' : value
      end
    end
  end

  def interpolate_method(method_key)
    @@interpolate_methods ||= begin
      global_lookup = lambda do |key, lookup_invocation, _|
        scope = lookup_invocation.scope
        if scope.is_a?(Hiera::Scope) && !lookup_invocation.global_only?
          # "unwrap" the Hiera::Scope
          scope = scope.real
        end
        lookup_invocation.with_scope(scope) do |sub_invocation|
          sub_invocation.lookup(key) {  Lookup.lookup(key, nil, '', true, nil, sub_invocation) }
        end
      end
      scope_lookup = lambda do |key, lookup_invocation, subject|
        segments = split_key(key) { |problem| Puppet::DataBinding::LookupError.new("#{problem} in string: #{subject}") }
        root_key = segments.shift
        value = lookup_invocation.with(:scope, 'Global Scope') do
          ovr = lookup_invocation.override_values
          if ovr.include?(root_key)
            lookup_invocation.report_found_in_overrides(root_key, ovr[root_key])
          else
            scope = lookup_invocation.scope
            val = scope[root_key]
            if val.nil? && !nil_in_scope?(scope, root_key)
              defaults = lookup_invocation.default_values
              if defaults.include?(root_key)
                lookup_invocation.report_found_in_defaults(root_key, defaults[root_key])
              else
                nil
              end
            else
              lookup_invocation.report_found(root_key, val)
            end
          end
        end
        unless value.nil? || segments.empty?
          found = nil;
          catch(:no_such_key) { found = sub_lookup(key, lookup_invocation, segments, value) }
          value = found;
        end
        lookup_invocation.remember_scope_lookup(key, root_key, segments, value)
        value
      end

      {
        :lookup => global_lookup,
        :hiera => global_lookup, # this is just an alias for 'lookup'
        :alias => global_lookup, # same as 'lookup' but expression must be entire string and result is not subject to string substitution
        :scope => scope_lookup,
        :literal => lambda { |key, _, _| key }
      }.freeze
    end
    interpolate_method = @@interpolate_methods[method_key]
    fail(Issues::HIERA_INTERPOLATION_UNKNOWN_INTERPOLATION_METHOD, :name => method_key) unless interpolate_method
    interpolate_method
  end

  # Because the semantics of Puppet::Parser::Scope#include? differs from Hash#include?
  def nil_in_scope?(scope, key)
    if scope.is_a?(Hash)
      scope.include?(key)
    else
      scope.exist?(key)
    end
  end

  def get_method_and_data(data, allow_methods)
    if match = data.match(/^(\w+)\((?:["]([^"]+)["]|[']([^']+)['])\)$/)
      fail(Issues::HIERA_INTERPOLATION_METHOD_SYNTAX_NOT_ALLOWED) unless allow_methods
      key = match[1].to_sym
      data = match[2] || match[3] # double or single qouted
    else
      key = :scope
    end
    [key, data]
  end

  def fail(issue, args = EMPTY_HASH)
    raise Puppet::DataBinding::LookupError.new(
      issue.format(args), nil, nil, nil, nil, issue.issue_code)
  end
end
end
end
