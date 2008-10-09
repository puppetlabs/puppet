class UserAttr
    def self.get_attributes_by_name(name)
        attributes = nil

        File.readlines('/etc/user_attr').each do |line|
            next if line =~ /^#/

            token = line.split(':')

            if token[0] == name
                attributes = {:name => name}
                token[4].split(';').each do |attr|
                    key_value = attr.split('=')
                    attributes[key_value[0].intern] = key_value[1].strip
                end
                break
            end
        end
        return attributes
    end
end
