# This class defines the API of the MigrationChecker support.
#
class Puppet::Pops::Migration::MigrationChecker

  def initialize()
  end

  def report_ambiguous_integer(o)
  end

  def report_ambiguous_float(o)
  end

  def report_empty_string_true(value, o)
  end

  def report_uc_bareword_type(value, o)
  end
end