# This class defines the private API of the MigrationChecker support.
# @api private
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

  def report_equality_type_mismatch(left, right, o)
  end

  def report_option_type_mismatch(test_value, option_value, option_expr, matching_expr)
  end

  def report_in_expression(o)
  end

  def report_array_last_in_block(o)
  end
end
