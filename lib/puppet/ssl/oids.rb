require 'puppet/ssl'

# This module defines OIDs for use within Puppet.
#
# == ASN.1 Definition
#
# The following is the formal definition of OIDs specified in this file.
#
# puppetCertExtensions OBJECT IDENTIFIER ::= {iso(1) identified-organization(3)
#    dod(6) internet(1) private(4) enterprise(1) 34380 1}
#
# -- the tree under registeredExtensions 'belongs' to puppetlabs
# -- privateExtensions can be extended by enterprises to suit their own needs
# registeredExtensions OBJECT IDENTIFIER ::= { puppetCertExtensions 1 }
# privateExtensions OBJECT IDENTIFIER ::= { puppetCertExtensions 2 }
#
# -- subtree of common registered extensions
# -- The short names for these OIDs are intentionally lowercased and formatted
# -- since they may be exposed inside the Puppet DSL as variables.
# pp_uuid  OBJECT IDENTIFIER ::= { registeredExtensions 1 }
# pp_instance_id OBJECT IDENTIFIER ::= { registeredExtensions 2 }
# pp_image_name OBJECT IDENTIFIER ::= { registeredExtensions 3 }
# pp_preshared_key OBJECT IDENTIFIER ::= { registeredExtensions 4 }
#
# @api private
module Puppet::SSL::Oids

  PUPPET_OIDS = [
    ["1.3.6.1.4.1.34380", 'puppetlabs', 'Puppet Labs'],
    ["1.3.6.1.4.1.34380.1", 'ppCertExt', 'Puppet Certificate Extension'],

    ["1.3.6.1.4.1.34380.1.1", 'ppRegCertExt', 'Puppet Registered Certificate Extension'],

    ["1.3.6.1.4.1.34380.1.1.1", 'pp_uuid', 'Puppet Node UUID'],
    ["1.3.6.1.4.1.34380.1.1.2", 'pp_instance_id', 'Puppet Node Instance ID'],
    ["1.3.6.1.4.1.34380.1.1.3", 'pp_image_name', 'Puppet Node Image Name'],
    ["1.3.6.1.4.1.34380.1.1.4", 'pp_preshared_key', 'Puppet Node Preshared Key'],

    ["1.3.6.1.4.1.34380.1.2", 'ppPrivCertExt', 'Puppet Private Certificate Extension'],
  ]

  PUPPET_OIDS.each do |oid_defn|
    OpenSSL::ASN1::ObjectId.register(*oid_defn)
  end

  # Determine if the first OID contains the second OID
  #
  # @param first [String] The containing OID, in dotted form or as the short name
  # @param second [String] The contained OID, in dotted form or as the short name
  # @param exclusive [true, false] If an OID should not be considered as a subtree of itself
  #
  # @example Comparing two dotted OIDs
  #   Puppet::SSL::Oids.subtree_of?('1.3.6.1', '1.3.6.1.4.1') #=> true
  #   Puppet::SSL::Oids.subtree_of?('1.3.6.1', '1.3.6') #=> false
  #
  # @example Comparing an OID short name with a dotted OID
  #   Puppet::SSL::Oids.subtree_of?('IANA', '1.3.6.1.4.1') #=> true
  #   Puppet::SSL::Oids.subtree_of?('1.3.6.1', 'enterprises') #=> true
  #
  # @example Comparing an OID against itself
  #   Puppet::SSL::Oids.subtree_of?('IANA', 'IANA') #=> true
  #   Puppet::SSL::Oids.subtree_of?('IANA', 'IANA', true) #=> false
  #
  # @return [true, false]
  def self.subtree_of?(first, second, exclusive = false)
    first_oid = OpenSSL::ASN1::ObjectId.new(first).oid
    second_oid = OpenSSL::ASN1::ObjectId.new(second).oid


    if exclusive and first_oid == second_oid
      false
    else
      second_oid.index(first_oid) == 0
    end
  rescue OpenSSL::ASN1::ASN1Error
    false
  end
end
