# Decrypts given Encrypted value for the local host and returns a `Sensitive` value with the decrypted value.
#
# @example Encrypt and decrypt in apply mode
#   $encrypted = Encrypted("Area 51 - the aliens are alive and well")
#   $clear = decrypt($encrypted).unwrap
#
# Typically the result of encryption is for a resource where the encrypted value is used as the
# value of an attribute and where the resource type is not prepared to handle the decryption (since
# all existing resource types predates the existence of Encrypted).
# To be able to send the encrypted value and to give the resource a Sensitive decrypted
# value a `Deferred` value is used as that will decrypt the value without the resource type
# having to have any knowledge of Encrypted.
#
# @example Using a Deferred value to decrypt on node - with Sensitive input
#   class mymodule::myclass(Sensitive $password) {
#     mymodule::myresource { 'example':
#       password => Deferred('decrypt', encrypt($password))
#     }
#   }
#
#
# @example Using a Deferred value to decrypt on node - with input being clear text
#   class mymodule::myclass(String $password) {
#     mymodule::myresource { 'example':
#       password => Deferred('decrypt', Encrypt($password))
#     }
#   }
#
# In both of the example above, the resulting value assigned to the `password` is marked as `Sensitive`
#
# See `encrypt()` for details about encryption.
#
# @Since 5.5.x - TBD
#
Puppet::Functions.create_function(:decrypt) do
  require 'openssl'

  dispatch :decrypt_encrypted do
    param 'Encrypted', :encrypted_data
    optional_param 'String', :node_name
  end

  def decrypt_encrypted(encrypted, node_name = nil)
    if node_name
      host = Puppet::SSL::Host.new(node_name)
      encrypted.decrypt(closure_scope, host)
    else
      encrypted.decrypt(closure_scope)
    end
  end
end
