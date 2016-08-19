require 'yaml'

module Puppet::Util::Yaml
  if defined?(::Psych::SyntaxError)
    YamlLoadExceptions = [::StandardError, ::Psych::SyntaxError]
  else
    YamlLoadExceptions = [::StandardError]
  end

  class YamlLoadError < Puppet::Error; end

  def self.load_file(filename, default_value = false, strip_classes = false)
    if(strip_classes) then
      data = YAML::parse_file(filename)
      data.root.each do |o|
        if o.respond_to?(:tag=) and
           o.tag != nil and
           o.tag.start_with?("!ruby")
          o.tag = nil
        end
      end
      data.to_ruby || default_value
    else
      yaml = YAML.load_file(filename)
      yaml || default_value
    end
  rescue *YamlLoadExceptions => detail
    raise YamlLoadError.new(detail.message, detail)
  end

  def self.dump(structure, filename)
    Puppet::Util.replace_file(filename, 0660) do |fh|
      YAML.dump(structure, fh)
    end
  end
end
