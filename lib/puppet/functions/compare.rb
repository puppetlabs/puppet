# frozen_string_literal: true

# Compares two values and returns -1, 0 or 1 if first value is smaller, equal or larger than the second value.
# The compare function accepts arguments of the data types `String`, `Numeric`, `Timespan`, `Timestamp`, and `Semver`,
# such that:
#
# * two of the same data type can be compared
# * `Timespan` and `Timestamp` can be compared with each other and with `Numeric`
#
# When comparing two `String` values the comparison can be made to consider case by passing a third (optional)
# boolean `false` value - the default is `true` which ignores case as the comparison operators
# in the Puppet Language.
#
Puppet::Functions.create_function(:compare) do
  local_types do
    type 'TimeComparable = Variant[Numeric, Timespan, Timestamp]'
    type 'Comparable = Variant[String, Semver, TimeComparable]'
  end

  dispatch :on_numeric do
    param 'Numeric', :a
    param 'Numeric', :b
  end

  dispatch :on_string do
    param 'String', :a
    param 'String', :b
    optional_param 'Boolean', :ignore_case
  end

  dispatch :on_version do
    param 'Semver', :a
    param 'Semver', :b
  end

  dispatch :on_time_num_first do
    param 'Numeric', :a
    param 'Variant[Timespan, Timestamp]', :b
  end

  dispatch :on_timestamp do
    param 'Timestamp', :a
    param 'Variant[Timestamp, Numeric]', :b
  end

  dispatch :on_timespan do
    param 'Timespan', :a
    param 'Variant[Timespan, Numeric]', :b
  end

  argument_mismatch :on_error do
    param 'Comparable', :a
    param 'Comparable', :b
    repeated_param 'Any', :ignore_case
  end

  argument_mismatch :on_not_comparable do
    param 'Any', :a
    param 'Any', :b
    repeated_param 'Any', :ignore_case
  end

  def on_numeric(a, b)
    a <=> b
  end

  def on_string(a, b, ignore_case = true)
    if ignore_case
      a.casecmp(b)
    else
      a <=> b
    end
  end

  def on_version(a, b)
    a <=> b
  end

  def on_time_num_first(a, b)
    # Time data types can compare against Numeric but not the other way around
    # the comparison is therefore done in reverse and the answer is inverted.
    -(b <=> a)
  end

  def on_timespan(a, b)
    a <=> b
  end

  def on_timestamp(a, b)
    a <=> b
  end

  def on_not_comparable(a, b, *ignore_case)
    # TRANSLATORS 'compare' is a name
    _("compare(): Non comparable type. Only values of the types Numeric, String, Semver, Timestamp and Timestamp can be compared. Got %{type_a} and %{type_b}") % {
      type_a: type_label(a), type_b: type_label(b)
    }
  end

  def on_error(a, b, *ignore_case)
    unless ignore_case.empty?
      unless a.is_a?(String) && b.is_a?(String)
        # TRANSLATORS 'compare' is a name
        return _("compare(): The third argument (ignore case) can only be used when comparing strings")
      end
      unless ignore_case.size == 1
        # TRANSLATORS 'compare' is a name
        return _("compare(): Accepts at most 3 arguments, got %{actual_number}") % { actual_number: 2 + ignore_case.size }
      end
      unless ignore_case[0].is_a?(Boolean)
        # TRANSLATORS 'compare' is a name
        return _("compare(): The third argument (ignore case) must be a Boolean. Got %{type}") % { type: type_label(ignore_case[0]) }
      end
    end

    if a.class != b.class
      # TRANSLATORS 'compare' is a name
      return _("compare(): Can only compare values of the same type (or for Timestamp/Timespan also against Numeric). Got %{type_a} and %{type_b}") % {
        type_a: type_label(a), type_b: type_label(b)
      }
    end
  end

  def type_label(x)
    Puppet::Pops::Model::ModelLabelProvider.new.label(x)
  end
end
