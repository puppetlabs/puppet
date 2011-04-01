# -*- coding: utf-8 -*-
require 'puppet/string'
require 'puppet/string/option'

class Puppet::String::Action
  attr_reader :name

  def to_s
    "#{@string}##{@name}"
  end

  def initialize(string, name, attrs = {})
    raise "#{name.inspect} is an invalid action name" unless name.to_s =~ /^[a-z]\w*$/
    @string  = string
    @name    = name.to_sym
    @options = {}
    attrs.each do |k, v| send("#{k}=", v) end
  end

  # Initially, this was defined to allow the @action.invoke pattern, which is
  # a very natural way to invoke behaviour given our introspection
  # capabilities.   Heck, our initial plan was to have the string delegate to
  # the action object for invocation and all.
  #
  # It turns out that we have a binding problem to solve: @string was bound to
  # the parent class, not the subclass instance, and we don't pass the
  # appropriate context or change the binding enough to make this work.
  #
  # We could hack around it, by either mandating that you pass the context in
  # to invoke, or try to get the binding right, but that has probably got
  # subtleties that we don't instantly think of – especially around threads.
  #
  # So, we are pulling this method for now, and will return it to life when we
  # have the time to resolve the problem.  For now, you should replace...
  #
  #     @action = @string.get_action(name)
  #     @action.invoke(arg1, arg2, arg3)
  #
  # ...with...
  #
  #     @action = @string.get_action(name)
  #     @string.send(@action.name, arg1, arg2, arg3)
  #
  # I understand that is somewhat cumbersome, but it functions as desired.
  # --daniel 2011-03-31
  #
  # PS: This code is left present, but commented, to support this chunk of
  # documentation, for the benefit of the reader.
  #
  # def invoke(*args, &block)
  #   @string.send(name, *args, &block)
  # end

  def invoke=(block)
    if @string.is_a?(Class)
      @string.define_method(@name, &block)
    else
      @string.meta_def(@name, &block)
    end
  end

  def add_option(option)
    option.aliases.each do |name|
      if conflict = get_option(name) then
        raise ArgumentError, "Option #{option} conflicts with existing option #{conflict}"
      elsif conflict = @string.get_option(name) then
        raise ArgumentError, "Option #{option} conflicts with existing option #{conflict} on #{@string}"
      end
    end

    option.aliases.each do |name|
      @options[name] = option
    end

    option
  end

  def option?(name)
    @options.include? name.to_sym
  end

  def options
    (@options.keys + @string.options).sort
  end

  def get_option(name)
    @options[name.to_sym] || @string.get_option(name)
  end
end
