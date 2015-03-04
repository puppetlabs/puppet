# Patch to improve generated addXXX and setXXX method performance
#
# Submitted to rgen as PR: https://github.com/mthiede/rgen/pull/22. This
# patch should be removed once that PR has been included in an rgen
# release.
#
# The current implementation of the generated addXXX method will iterate
# over the contained array where each iteration will then test for object_id
# equality. Once the iteration is done and such an entry is found it
# checks if the added value is an instance of MMBase or MMGeneric. If it
# is, then it's considered a duplicate and the method returns.
#
# This patch changes the implementation so that the test for MMBase/
# MMGeneric is made prior to the iteration, thus avoiding the iteration
# alltogether for all non model objects
#
# The patch also changes the setXXX method to allow it to optimize the way
# it ensures that the added elements are unique. Calling the addXXX method
# to do an increasingly expensive sequential scan is very expensive when
# large sets of values are assigned.
#
require 'rgen/util/name_helper'
require 'rgen/metamodel_builder/constant_order_helper'
require 'rgen/metamodel_builder/builder_extensions'

module RGen
module MetamodelBuilder
module BuilderExtensions

  def _build_many_methods(props, other_props=nil)
    name = props.value(:name)
    other_role = other_props && other_props.value(:name)

    if props.value(:derived)
      build_derived_method(name, props, :many)
    else
      @@many_read_builder ||= ERB.new <<-CODE

          def get<%= firstToUpper(name) %>
            ( @<%= name %> ? @<%= name %>.dup : [] )
          end
          <% if name != "class" %>
            alias <%= name %> get<%= firstToUpper(name) %>
          <% end %>

      CODE
      self::ClassModule.module_eval(@@many_read_builder.result(binding))
    end

    if props.value(:changeable)
      @@many_write_builder ||= ERB.new <<-CODE

          def add<%= firstToUpper(name) %>(val, index=-1)
            @<%= name %> = [] unless @<%= name %>
            return if val.nil? || (val.is_a?(MMBase) || val.is_a?(MMGeneric)) && @<%= name %>.any? {|e| e.equal?(val)}
            <%= type_check_code("val", props) %>
            @<%= name %>.insert(index, val)
            <% if other_role %>
              val._register<%= firstToUpper(other_role) %>(self) unless val.is_a?(MMGeneric)
            <% end %>
            <% if props.reference? && props.value(:containment) %>
              val._set_container(self, :<%= name %>)
            <% end %>
          end

          def remove<%= firstToUpper(name) %>(val)
            @<%= name %> = [] unless @<%= name %>
            @<%= name %>.each_with_index do |e,i|
              if e.equal?(val)
                @<%= name %>.delete_at(i)
                <% if props.reference? && props.value(:containment) %>
                  val._set_container(nil, nil)
                <% end %>
                <% if other_role %>
                  val._unregister<%= firstToUpper(other_role) %>(self) unless val.is_a?(MMGeneric)
                <% end %>
                return
              end
            end
          end

          def set<%= firstToUpper(name) %>(val)
            return if val.nil?
            raise _assignmentTypeError(self, val, Enumerable) unless val.is_a? Enumerable
            get<%= firstToUpper(name) %>.each {|e|
              remove<%= firstToUpper(name) %>(e)
            }
            @<%= name %> = [] unless @<%= name %>
            <% if props.reference? %>
            val.uniq {|elem| elem.object_id }.each {|elem|
              next if elem.nil?
              <%= type_check_code("elem", props) %>
              @<%= name %> << elem
              <% if other_role %>
                elem._register<%= firstToUpper(other_role) %>(self) unless elem.is_a?(MMGeneric)
              <% end %>
              <% if props.value(:containment) %>
                elem._set_container(self, :<%= name %>)
              <% end %>
            }
            <% else %>
            val.each {|elem|
              <%= type_check_code("elem", props) %>
              @<%= name %> << elem
           }
           <% end %>
          end
          alias <%= name %>= set<%= firstToUpper(name) %>

          def _register<%= firstToUpper(name) %>(val)
            @<%= name %> = [] unless @<%= name %>
            @<%= name %>.push val
            <% if props.reference? && props.value(:containment) %>
              val._set_container(self, :<%= name %>)
            <% end %>
          end

          def _unregister<%= firstToUpper(name) %>(val)
            @<%= name %>.delete val
            <% if props.reference? && props.value(:containment) %>
              val._set_container(nil, nil)
            <% end %>
          end

      CODE
      self::ClassModule.module_eval(@@many_write_builder.result(binding))
    end
  end
end
end
end

