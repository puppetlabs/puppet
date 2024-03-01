# frozen_string_literal: true

class Puppet::Settings::AliasSetting
  attr_reader :name, :alias_name

  def initialize(args = {})
    @name = args[:name]
    @alias_name = args[:alias_for]
    @alias_for = Puppet.settings.setting(alias_name)
  end

  def optparse_args
    args = @alias_for.optparse_args
    args[0].gsub!(alias_name.to_s, name.to_s)
    args
  end

  def getopt_args
    args = @alias_for.getopt_args
    args[0].gsub!(alias_name.to_s, name.to_s)
    args
  end

  def type
    :alias
  end

  def method_missing(method, *args)
    alias_for.send(method, *args)
  rescue => e
    Puppet.log_exception(self.class, e.message)
  end

  private

  attr_reader :alias_for
end
