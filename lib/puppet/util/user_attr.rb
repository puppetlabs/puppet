# frozen_string_literal: true

class UserAttr
  def self.get_attributes_by_name(name)
    attributes = nil

    File.readlines('/etc/user_attr').each do |line|
      next if line =~ /^#/

      token = line.split(':')

      next unless token[0] == name

      attributes = { :name => name }
      token[4].split(';').each do |attr|
        key_value = attr.split('=')
        attributes[key_value[0].intern] = key_value[1].strip
      end
      break
    end
    attributes
  end
end
