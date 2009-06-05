## better-definers.rb --- better attribute and method definers
# Copyright (C) 2005  Daniel Brockman

# This program is free software; you can redistribute it
# and/or modify it under the terms of the GNU General Public
# License as published by the Free Software Foundation;
# either version 2 of the License, or (at your option) any
# later version.

# This file is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.

# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301, USA.

class Symbol
    def predicate?
        to_s.include? "?" end
    def imperative?
        to_s.include? "!" end
    def writer?
        to_s.include? "=" end

    def punctuated?
        predicate? or imperative? or writer? end
    def without_punctuation
        to_s.delete("?!=").to_sym end

    def predicate
        without_punctuation.to_s + "?" end
    def imperative
        without_punctuation.to_s + "!" end
    def writer
        without_punctuation.to_s + "=" end
end

class Hash
    def collect! (&block)
        replace Hash[*collect(&block).flatten]
    end

    def flatten
        to_a.flatten
    end
end

module Kernel
    def returning (value)
        yield value ; value
    end
end

class Module
    def define_hard_aliases (name_pairs)
        for new_aliases, existing_name in name_pairs do
            new_aliases.kind_of? Array or new_aliases = [new_aliases]
            for new_alias in new_aliases do
                alias_method(new_alias, existing_name)
            end
        end
    end

    def define_soft_aliases (name_pairs)
        for new_aliases, existing_name in name_pairs do
            new_aliases.kind_of? Array or new_aliases = [new_aliases]
            for new_alias in new_aliases do
                class_eval %{def #{new_alias}(*args, &block)
                            #{existing_name}(*args, &block) end}
            end
        end
    end

    define_soft_aliases \
        :define_hard_alias => :define_hard_aliases,
        :define_soft_alias => :define_soft_aliases

    # This method lets you define predicates like :foo?,
    # which will be defined to return the value of @foo.
    def define_readers (*names)
        for name in names.map { |x| x.to_sym } do
            if name.punctuated?
                # There's no way to define an efficient reader whose
                # name is different from the instance variable.
                class_eval %{def #{name} ; @#{name.without_punctuation} end}
            else
                # Use `attr_reader' to define an efficient method.
                attr_reader(name)
            end
        end
    end

    def writer_defined? (name)
        method_defined? name.to_sym.writer
    end

    # If you pass a predicate symbol :foo? to this method, it'll first
    # define a regular writer method :foo, without a question mark.
    # Then it'll define an imperative writer method :foo! as a shorthand
    # for setting the property to true.
    def define_writers (*names, &body)
        for name in names.map { |x| x.to_sym } do
            if block_given?
                define_method(name.writer, &body)
            else
                attr_writer(name.without_punctuation)
            end
            if name.predicate?
                class_eval %{def #{name.imperative}
                           self.#{name.writer} true end}
            end
        end
    end

    define_soft_aliases \
        :define_reader => :define_readers,
        :define_writer => :define_writers

    # We don't need a singular alias for `define_accessors',
    # because it always defines at least two methods.

    def define_accessors (*names)
        define_readers(*names)
        define_writers(*names)
    end

    def define_opposite_readers (name_pairs)
        name_pairs.collect! { |k, v| [k.to_sym, v.to_sym] }
        for opposite_name, name in name_pairs do
            define_reader(name) unless method_defined? name
            class_eval %{def #{opposite_name} ; not #{name} end}
        end
    end

    def define_opposite_writers (name_pairs)
        name_pairs.collect! { |k, v| [k.to_sym, v.to_sym] }
        for opposite_name, name in name_pairs do
            define_writer(name) unless writer_defined? name
            class_eval %{def #{opposite_name.writer} x
                         self.#{name.writer} !x end}
            class_eval %{def #{opposite_name.imperative}
                         self.#{name.writer} false end}
        end
    end

    define_soft_aliases \
        :define_opposite_reader => :define_opposite_readers,
        :define_opposite_writer => :define_opposite_writers

    def define_opposite_accessors (name_pairs)
        define_opposite_readers name_pairs
        define_opposite_writers name_pairs
    end

    def define_reader_with_opposite (name_pair, &body)
        name, opposite_name = name_pair.flatten.collect { |x| x.to_sym }
        define_method(name, &body)
        define_opposite_reader(opposite_name => name)
    end

    def define_writer_with_opposite (name_pair, &body)
        name, opposite_name = name_pair.flatten.collect { |x| x.to_sym }
        define_writer(name, &body)
        define_opposite_writer(opposite_name => name)
    end

  public :define_method

    def define_methods (*names, &body)
        names.each { |name| define_method(name, &body) }
    end

    def define_private_methods (*names, &body)
        define_methods(*names, &body)
        names.each { |name| private name }
    end

    def define_protected_methods (*names, &body)
        define_methods(*names, &body)
        names.each { |name| protected name }
    end

    def define_private_method (name, &body)
        define_method(name, &body)
        private name
    end

    def define_protected_method (name, &body)
        define_method(name, &body)
        protected name
    end
end

class ImmutableAttributeError < StandardError
    def initialize (attribute=nil, message=nil)
        super message
        @attribute = attribute
    end

    define_accessors :attribute

    def to_s
        if @attribute and @message
            "cannot change the value of `#@attribute': #@message"
        elsif @attribute
            "cannot change the value of `#@attribute'"
        elsif @message
            "cannot change the value of attribute: #@message"
        else
            "cannot change the value of attribute"
        end
    end
end

class Module
    # Guard each of the specified attributes by replacing the writer
    # method with a proxy that asks the supplied block before proceeding
    # with the change.
    #
    # If it's okay to change the attribute, the block should return
    # either nil or the symbol :mutable.  If it isn't okay, the block
    # should return a string saying why the attribute can't be changed.
    # If you don't want to provide a reason, you can have the block
    # return just the symbol :immutable.
    def guard_writers(*names, &predicate)
        for name in names.map { |x| x.to_sym } do
            define_hard_alias("__unguarded_#{name.writer}" => name.writer)
            define_method(name.writer) do |new_value|
                case result = predicate.call
                when :mutable, nil
                    __send__("__unguarded_#{name.writer}", new_value)
                when :immutable
                    raise ImmutableAttributeError.new(name)
                else
                    raise ImmutableAttributeError.new(name, result)
                end
            end
        end
    end

    def define_guarded_writers (*names, &block)
        define_writers(*names)
        guard_writers(*names, &block)
    end

    define_soft_alias :guard_writer => :guard_writers
    define_soft_alias :define_guarded_writer => :define_guarded_writers
end

if __FILE__ == $0
    require "test/unit"

    class DefineAccessorsTest < Test::Unit::TestCase
        def setup
            @X = Class.new
            @Y = Class.new @X
            @x = @X.new
            @y = @Y.new
        end

        def test_define_hard_aliases
            @X.define_method(:foo) { 123 }
            @X.define_method(:baz) { 321 }
            @X.define_hard_aliases :bar => :foo, :quux => :baz
            assert_equal @x.foo, 123
            assert_equal @x.bar, 123
            assert_equal @y.foo, 123
            assert_equal @y.bar, 123
            assert_equal @x.baz, 321
            assert_equal @x.quux, 321
            assert_equal @y.baz, 321
            assert_equal @y.quux, 321
            @Y.define_method(:foo) { 456 }
            assert_equal @y.foo, 456
            assert_equal @y.bar, 123
            @Y.define_method(:quux) { 654 }
            assert_equal @y.baz, 321
            assert_equal @y.quux, 654
        end

        def test_define_soft_aliases
            @X.define_method(:foo) { 123 }
            @X.define_method(:baz) { 321 }
            @X.define_soft_aliases :bar => :foo, :quux => :baz
            assert_equal @x.foo, 123
            assert_equal @x.bar, 123
            assert_equal @y.foo, 123
            assert_equal @y.bar, 123
            assert_equal @x.baz, 321
            assert_equal @x.quux, 321
            assert_equal @y.baz, 321
            assert_equal @y.quux, 321
            @Y.define_method(:foo) { 456 }
            assert_equal @y.foo, @y.bar, 456
            @Y.define_method(:quux) { 654 }
            assert_equal @y.baz, 321
            assert_equal @y.quux, 654
        end

        def test_define_readers
            @X.define_readers :foo, :bar
            assert !@x.respond_to?(:foo=)
            assert !@x.respond_to?(:bar=)
            @x.instance_eval { @foo = 123 ; @bar = 456 }
            assert_equal @x.foo, 123
            assert_equal @x.bar, 456
            @X.define_readers :baz?, :quux?
            assert !@x.respond_to?(:baz=)
            assert !@x.respond_to?(:quux=)
            @x.instance_eval { @baz = false ; @quux = true }
            assert !@x.baz?
            assert @x.quux?
        end

        def test_define_writers
            assert !@X.writer_defined?(:foo)
            assert !@X.writer_defined?(:bar)
            @X.define_writers :foo, :bar
            assert @X.writer_defined?(:foo)
            assert @X.writer_defined?(:bar)
            assert @X.writer_defined?(:foo=)
            assert @X.writer_defined?(:bar=)
            assert @X.writer_defined?(:foo?)
            assert @X.writer_defined?(:bar?)
            assert !@x.respond_to?(:foo)
            assert !@x.respond_to?(:bar)
            @x.foo = 123
            @x.bar = 456
            assert_equal @x.instance_eval { @foo }, 123
            assert_equal @x.instance_eval { @bar }, 456
            @X.define_writers :baz?, :quux?
            assert !@x.respond_to?(:baz?)
            assert !@x.respond_to?(:quux?)
            @x.baz = true
            @x.quux = false
            assert_equal @x.instance_eval { @baz }, true
            assert_equal @x.instance_eval { @quux }, false
        end

        def test_define_accessors
            @X.define_accessors :foo, :bar
            @x.foo = 123 ; @x.bar = 456
            assert_equal @x.foo, 123
            assert_equal @x.bar, 456
        end

        def test_define_opposite_readers
            @X.define_opposite_readers :foo? => :bar?, :baz? => :quux?
            assert !@x.respond_to?(:foo=)
            assert !@x.respond_to?(:bar=)
            assert !@x.respond_to?(:baz=)
            assert !@x.respond_to?(:quux=)
            @x.instance_eval { @bar = true ; @quux = false }
            assert !@x.foo?
            assert @x.bar?
            assert @x.baz?
            assert !@x.quux?
        end

        def test_define_opposite_writers
            @X.define_opposite_writers :foo? => :bar?, :baz => :quux
        end
    end
end
