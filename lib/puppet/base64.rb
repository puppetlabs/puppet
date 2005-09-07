# a stupid hack class to get rid of all of the warnings but
# still make the encode/decode methods available

# 1.8.2 has a Base64 class, but 1.8.1 just imports the methods directly
# into Object

require 'base64'

unless defined? Base64
    class Base64
        def Base64.encode64(*args)
            Object.method(:encode64).call(*args)
        end

        def Base64.decode64(*args)
            Object.method(:decode64).call(*args)
        end
    end
end
