# frozen_string_literal: true

# Convert arguments into booleans, integers, or whatever.
class Puppet::Settings::ValueTranslator
  def [](value)
    # Handle different data types correctly
    case value
    when /^false$/i; false
    when /^true$/i; true
    when true; true
    when false; false
    else
      value.gsub(/^["']|["']$/, '').sub(/\s+$/, '')
    end
  end
end
