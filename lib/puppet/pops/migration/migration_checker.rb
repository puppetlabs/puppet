# This class defines the private API of the MigrationChecker support.
# @api private
#
class Puppet::Pops::Migration::MigrationChecker

  def initialize()
  end

  # Produces a hash of available migrations; a map from a symbolic name in string form to a brief description.
  def available_migrations()
    { '3.8/4.0' => '3.8 future parser to 4.0 language migrations'}
  end

  # For 3.8/4.0
  def report_ambiguous_integer(o)
  end

  # For 3.8/4.0
  def report_ambiguous_float(o)
  end

  # For 3.8/4.0
  def report_empty_string_true(value, o)
  end

  # For 3.8/4.0
  def report_uc_bareword_type(value, o)
  end

  # For 3.8/4.0
  def report_equality_type_mismatch(left, right, o)
  end

  # For 3.8/4.0
  def report_option_type_mismatch(test_value, option_value, option_expr, matching_expr)
  end

  # For 3.8/4.0
  def report_in_expression(o)
  end

  # For 3.8/4.0
  def report_array_last_in_block(o)
  end
end
