# Convert arguments into booleans, integers, or whatever.
class Puppet::Settings::ValueTranslator
  def [](value)
    # Handle different data types correctly
    return case value
      when /^false$/i; false
      when /^true$/i; true
      when /^\d+$/i; Integer(value)
      when true; true
      when false; false
      else
        value.gsub(/^["']|["']$/,'').sub(/\s+$/, '')
    end
  end
end
