# coding: utf-8
test_name "Windows Service Provider With Mixed UTF-8 Service Names" do
  confine :to, :platform => 'windows'

  tag 'audit:high',
      'audit:acceptance'

  require 'puppet/acceptance/windows_utils'
  extend Puppet::Acceptance::WindowsUtils

  def service_manifest(name, params)
    params_str = params.map do |param, value|
      value_str = value.to_s
      value_str = "\"#{value_str}\"" if value.is_a?(String)

      "  #{param} => #{value_str}"
    end.join(",\n")

    <<-MANIFEST
service { '#{name}':
  #{params_str}
}
MANIFEST
  end

  [
    # different UTF-8 widths
    # 1-byte A
    # 2-byte ۿ - http://www.fileformat.info/info/unicode/char/06ff/index.htm - 0xDB 0xBF / 219 191
    # 3-byte ᚠ - http://www.fileformat.info/info/unicode/char/16A0/index.htm - 0xE1 0x9A 0xA0 / 225 154 160
    # 4-byte ܎ - http://www.fileformat.info/info/unicode/char/2070E/index.htm - 0xF0 0xA0 0x9C 0x8E / 240 160 156 142
    {
      :name => "A\u06FF\u16A0\u{2070E}",
      :start_sleep => 0,
      :pause_sleep => 0,
      :continue_sleep => 0,
      :stop_sleep => 0,
    }
  ].each do |mock_service|
    agents.each do |agent|
      pending_test("Windows 11 UTF-8 file paths") if agent['platform'] =~ /windows-11/

      setup_service(agent, mock_service, 'MockService.cs')

      step 'Verify that enable = false disables the service' do
        apply_manifest_on(agent, service_manifest(mock_service[:name], enable: false))
        assert_service_properties_on(agent, mock_service[:name], StartMode: 'Disabled')
      end

      step 'Verify that enable = manual indicates that the service can be started on demand' do
        apply_manifest_on(agent, service_manifest(mock_service[:name], enable: :manual))
        assert_service_properties_on(agent, mock_service[:name], StartMode: 'Manual')
      end

      step 'Verify that enable = delayed indicates that the service start mode is correctly set' do
        apply_manifest_on(agent, service_manifest(mock_service[:name], enable: :delayed))
        assert_service_startmode_delayed(agent, mock_service[:name])
      end

      step 'Verify that enable = true indicates that the service is started automatically upon reboot' do
        apply_manifest_on(agent, service_manifest(mock_service[:name], enable: true))
        assert_service_properties_on(agent, mock_service[:name], StartMode: 'Auto')
      end

      step 'Verify that we can start the service' do
        apply_manifest_on(agent, service_manifest(mock_service[:name], ensure: :running))
        assert_service_properties_on(agent, mock_service[:name], State: 'Running')
      end

      step 'Verify idempotence' do
        apply_manifest_on(agent, service_manifest(mock_service[:name], ensure: :running))
        assert_service_properties_on(agent, mock_service[:name], State: 'Running')
      end

      step 'Verify that we can stop the service' do
        apply_manifest_on(agent, service_manifest(mock_service[:name], ensure: :stopped))
        assert_service_properties_on(agent, mock_service[:name], State: 'Stopped')
      end
    end
  end
end
