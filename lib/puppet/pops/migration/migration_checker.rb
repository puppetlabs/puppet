# This class defines the private API of the MigrationChecker support.
# @api private
#
class Puppet::Pops::Migration::MigrationChecker

  def initialize()
  end

  def self.singleton
    @null_checker ||= self.new
  end

  # Produces a hash of available migrations; a map from a symbolic name in string form to a brief description.
  # This version has no such supported migrations.
  def available_migrations()
    { }
  end

  # For 3.8/4.0
  def report_ambiguous_integer(o)
    raise Puppet::DevError, _("Unsupported migration method called")
  end

  # For 3.8/4.0
  def report_ambiguous_float(o)
    raise Puppet::DevError, _("Unsupported migration method called")
  end

  # For 3.8/4.0
  def report_empty_string_true(value, o)
    raise Puppet::DevError, _("Unsupported migration method called")
  end

  # For 3.8/4.0
  def report_uc_bareword_type(value, o)
    raise Puppet::DevError, _("Unsupported migration method called")
  end

  # For 3.8/4.0
  def report_equality_type_mismatch(left, right, o)
    raise Puppet::DevError, _("Unsupported migration method called")
  end

  # For 3.8/4.0
  def report_option_type_mismatch(test_value, option_value, option_expr, matching_expr)
    raise Puppet::DevError, _("Unsupported migration method called")
  end

  # For 3.8/4.0
  def report_in_expression(o)
    raise Puppet::DevError, _("Unsupported migration method called")
  end

  # For 3.8/4.0
  def report_array_last_in_block(o)
    raise Puppet::DevError, _("Unsupported migration method called")
  end
end
