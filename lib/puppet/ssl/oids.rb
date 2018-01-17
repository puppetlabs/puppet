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
# authorizationExtensions OBJECT IDENTIFIER ::= { puppetCertExtensions 3 }
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

  # Note: When updating the following OIDs make sure to also update the OID
  # definitions here:
  # https://github.com/puppetlabs/puppetserver/blob/master/src/clj/puppetlabs/puppetserver/certificate_authority.clj#L122-L159

  PUPPET_OIDS = [
    ["1.3.6.1.4.1.34380", 'puppetlabs', 'Puppet Labs'],
    ["1.3.6.1.4.1.34380.1", 'ppCertExt', 'Puppet Certificate Extension'],

    ["1.3.6.1.4.1.34380.1.1", 'ppRegCertExt', 'Puppet Registered Certificate Extension'],

    ["1.3.6.1.4.1.34380.1.1.1", 'pp_uuid', 'Puppet Node UUID'],
    ["1.3.6.1.4.1.34380.1.1.2", 'pp_instance_id', 'Puppet Node Instance ID'],
    ["1.3.6.1.4.1.34380.1.1.3", 'pp_image_name', 'Puppet Node Image Name'],
    ["1.3.6.1.4.1.34380.1.1.4", 'pp_preshared_key', 'Puppet Node Preshared Key'],
    ["1.3.6.1.4.1.34380.1.1.5", 'pp_cost_center', 'Puppet Node Cost Center Name'],
    ["1.3.6.1.4.1.34380.1.1.6", 'pp_product', 'Puppet Node Product Name'],
    ["1.3.6.1.4.1.34380.1.1.7", 'pp_project', 'Puppet Node Project Name'],
    ["1.3.6.1.4.1.34380.1.1.8", 'pp_application', 'Puppet Node Application Name'],
    ["1.3.6.1.4.1.34380.1.1.9", 'pp_service', 'Puppet Node Service Name'],
    ["1.3.6.1.4.1.34380.1.1.10", 'pp_employee', 'Puppet Node Employee Name'],
    ["1.3.6.1.4.1.34380.1.1.11", 'pp_created_by', 'Puppet Node created_by Tag'],
    ["1.3.6.1.4.1.34380.1.1.12", 'pp_environment', 'Puppet Node Environment Name'],
    ["1.3.6.1.4.1.34380.1.1.13", 'pp_role', 'Puppet Node Role Name'],
    ["1.3.6.1.4.1.34380.1.1.14", 'pp_software_version', 'Puppet Node Software Version'],
    ["1.3.6.1.4.1.34380.1.1.15", 'pp_department', 'Puppet Node Department Name'],
    ["1.3.6.1.4.1.34380.1.1.16", 'pp_cluster', 'Puppet Node Cluster Name'],
    ["1.3.6.1.4.1.34380.1.1.17", 'pp_provisioner', 'Puppet Node Provisioner Name'],
    ["1.3.6.1.4.1.34380.1.1.18", 'pp_region', 'Puppet Node Region Name'],
    ["1.3.6.1.4.1.34380.1.1.19", 'pp_datacenter', 'Puppet Node Datacenter Name'],
    ["1.3.6.1.4.1.34380.1.1.20", 'pp_zone', 'Puppet Node Zone Name'],
    ["1.3.6.1.4.1.34380.1.1.21", 'pp_network', 'Puppet Node Network Name'],
    ["1.3.6.1.4.1.34380.1.1.22", 'pp_securitypolicy', 'Puppet Node Security Policy Name'],
    ["1.3.6.1.4.1.34380.1.1.23", 'pp_cloudplatform', 'Puppet Node Cloud Platform Name'],
    ["1.3.6.1.4.1.34380.1.1.24", 'pp_apptier', 'Puppet Node Application Tier'],
    ["1.3.6.1.4.1.34380.1.1.25", 'pp_hostname', 'Puppet Node Hostname'],

    ["1.3.6.1.4.1.34380.1.2", 'ppPrivCertExt', 'Puppet Private Certificate Extension'],

    ["1.3.6.1.4.1.34380.1.3", 'ppAuthCertExt', 'Puppet Certificate Authorization Extension'],

    ["1.3.6.1.4.1.34380.1.3.1",  'pp_authorization', 'Certificate Extension Authorization'],
    ["1.3.6.1.4.1.34380.1.3.13", 'pp_auth_role', 'Puppet Node Role Name for Authorization'],
  ]

  @did_register_puppet_oids = false

  # Register our custom Puppet OIDs with OpenSSL so they can be used as CSR
  # extensions. Without registering these OIDs, OpenSSL will fail when it
  # encounters such an extension in a CSR.
  def self.register_puppet_oids()
    if !@did_register_puppet_oids
      PUPPET_OIDS.each do |oid_defn|
        OpenSSL::ASN1::ObjectId.register(*oid_defn)
      end

      @did_register_puppet_oids = true
    end
  end

  # Parse custom OID mapping file that enables custom OIDs to be resolved
  # into user-friendly names.
  #
  # @param custom_oid_file [String] File to obtain custom OIDs mapping from
  # @param map_key [String] Hash key in which custom OIDs mapping is stored
  #
  # @example Custom OID mapping file
  # ---
  # oid_mapping:
  #  '1.3.6.1.4.1.34380.1.2.1.1':
  #    shortname : 'myshortname'
  #    longname  : 'Long name'
  #  '1.3.6.1.4.1.34380.1.2.1.2':
  #    shortname: 'myothershortname'
  #    longname: 'Other Long name'
  def self.parse_custom_oid_file(custom_oid_file, map_key='oid_mapping')
    if File.exists?(custom_oid_file) && File.readable?(custom_oid_file)
      mapping = nil
      begin
        mapping = YAML.load_file(custom_oid_file)
      rescue => err
        raise Puppet::Error, _("Error loading ssl custom OIDs mapping file from '%{custom_oid_file}': %{err}") % { custom_oid_file: custom_oid_file, err: err }, err.backtrace
      end

      unless mapping.has_key?(map_key)
        raise Puppet::Error, _("Error loading ssl custom OIDs mapping file from '%{custom_oid_file}': no such index '%{map_key}'") % { custom_oid_file: custom_oid_file, map_key: map_key }
      end

      unless mapping[map_key].is_a?(Hash)
        raise Puppet::Error, _("Error loading ssl custom OIDs mapping file from '%{custom_oid_file}': data under index '%{map_key}' must be a Hash") % { custom_oid_file: custom_oid_file, map_key: map_key }
      end

      oid_defns = []
      mapping[map_key].keys.each do |oid|
        shortname, longname = mapping[map_key][oid].values_at("shortname","longname")
        if shortname.nil? || longname.nil?
          raise Puppet::Error, _("Error loading ssl custom OIDs mapping file from '%{custom_oid_file}': incomplete definition of oid '%{oid}'") % { custom_oid_file: custom_oid_file, oid: oid }
        end
        oid_defns << [oid, shortname, longname]
      end

      oid_defns
    end
  end

  # Load custom OID mapping file that enables custom OIDs to be resolved
  # into user-friendly names.
  #
  # @param custom_oid_file [String] File to obtain custom OIDs mapping from
  # @param map_key [String] Hash key in which custom OIDs mapping is stored
  #
  # @example Custom OID mapping file
  # ---
  # oid_mapping:
  #  '1.3.6.1.4.1.34380.1.2.1.1':
  #    shortname : 'myshortname'
  #    longname  : 'Long name'
  #  '1.3.6.1.4.1.34380.1.2.1.2':
  #    shortname: 'myothershortname'
  #    longname: 'Other Long name'
  def self.load_custom_oid_file(custom_oid_file, map_key='oid_mapping')
    oid_defns = parse_custom_oid_file(custom_oid_file, map_key)
    unless oid_defns.nil?
      begin
        oid_defns.each do |oid_defn|
          OpenSSL::ASN1::ObjectId.register(*oid_defn)
        end
      rescue => err
        raise ArgumentError, _("Error registering ssl custom OIDs mapping from file '%{custom_oid_file}': %{err}") % { custom_oid_file: custom_oid_file, err: err }, err.backtrace
      end
    end
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
