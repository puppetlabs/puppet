require 'spec_helper'
require 'puppet/util/plist'

describe Puppet::Util::Plist do
  let(:valid_xml_plist) do
    '<?xml version="1.0" encoding="UTF-8"?>
     <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
     <plist version="1.0">
     <dict>
       <key>LastUsedPrinters</key>
       <array>
         <dict>
                 <key>Network</key>
                 <string>10.85.132.1</string>
                 <key>PrinterID</key>
                 <string>baskerville_corp_puppetlabs_net</string>
         </dict>
         <dict>
                 <key>Network</key>
                 <string>10.14.96.1</string>
                 <key>PrinterID</key>
                 <string>Statler</string>
         </dict>
       </array>
    </dict>
    </plist>'
  end
  let(:valid_xml_plist_hash) { {"LastUsedPrinters"=>[{"Network"=>"10.85.132.1", "PrinterID"=>"baskerville_corp_puppetlabs_net"}, {"Network"=>"10.14.96.1", "PrinterID"=>"Statler"}]} }
  let(:plist_path) { '/var/tmp/sample.plist' }
  let(:binary_plist_magic_number) { 'bplist00' }
  let(:bad_xml_doctype) { '<!DOCTYPE plist PUBLIC -//Apple Computer' }
  let(:good_xml_doctype) { '<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' }

  describe "#read_plist_file" do
    it "calls #convert_cfpropertylist_to_native_types on a plist object when a valid binary plist is read" do
      subject.stubs(:read_file_with_offset).with(plist_path, 8).returns(binary_plist_magic_number)
      subject.stubs(:new_cfpropertylist).with(plist_path).returns('plist_object')
      subject.expects(:convert_cfpropertylist_to_native_types).with('plist_object')
      subject.read_plist_file(plist_path)
    end
    it "returns a valid hash when a valid XML plist is read" do
      subject.stubs(:read_file_with_offset).with(plist_path, 8).returns('notbinary')
      subject.stubs(:open_file_with_args).with(plist_path, 'r:UTF-8').returns(valid_xml_plist)
      expect(subject.read_plist_file(plist_path)).to eq(valid_xml_plist_hash)
    end
    it "raises a debug message and replaces a bad XML plist doctype should one be encountered" do
      subject.stubs(:read_file_with_offset).with(plist_path, 8).returns('notbinary')
      subject.stubs(:open_file_with_args).with(plist_path, 'r:UTF-8').returns(bad_xml_doctype)
      subject.stubs(:convert_cfpropertylist_to_native_types).with('plist_object')
      subject.expects(:new_cfpropertylist).with(good_xml_doctype).returns('plist_object')
      Puppet.expects(:debug).with('Had to fix plist with incorrect DOCTYPE declaration: /var/tmp/sample.plist')
      subject.read_plist_file(plist_path)
    end
    it "raises a debug message with malformed plist files" do
      subject.stubs(:read_file_with_offset).with(plist_path, 8).returns('notbinary')
      subject.stubs(:open_file_with_args).with(plist_path, 'r:UTF-8').returns("<plist><dict><key>Foo</key>")
      subject.stubs(:convert_cfpropertylist_to_native_types).with('plist_object')
      Puppet.expects(:debug).with(regexp_matches(/^Failed with CFFormatError/))
      subject.read_plist_file(plist_path)
    end
  end
end
