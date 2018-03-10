require 'ffi'

# Puppet::Util::Windows::EventLog needs to be requirable without having loaded
# any other parts of Puppet so it can be leveraged independently by the code
# that runs Puppet as a service on Windows.
#
# For this reason we:
# - Define Puppet::Util::Windows
# - Replicate logic that exists elsewhere in puppet/util/windows
# - Raise generic RuntimeError instead of Puppet::Util::Windows::Error if its not defined
module Puppet; module Util; module Windows ; end ; end ; end

class Puppet::Util::Windows::EventLog
  extend FFI::Library

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa363679(v=vs.85).aspx
  EVENTLOG_ERROR_TYPE       = 0x0001
  EVENTLOG_WARNING_TYPE     = 0x0002
  EVENTLOG_INFORMATION_TYPE = 0x0004

  # These are duplicate definitions from Puppet::Util::Windows::ApiTypes,
  # established here so this class can be standalone from Puppet, and public so
  # we can reference them in tests.
  NULL_HANDLE = 0
  WIN32_FALSE = 0

  # Register an event log handle for the application
  # @param source_name [String] the name of the event source to retrieve a handle for
  # @return [void]
  # @api public
  def initialize(source_name = 'Puppet')
    @eventlog_handle = RegisterEventSourceW(FFI::Pointer::NULL, wide_string(source_name))
    if @eventlog_handle == NULL_HANDLE
      #TRANSLATORS 'Windows' is the operating system and 'RegisterEventSourceW' is a API call and should not be translated
      raise EventLogError.new(_("RegisterEventSourceW failed to open Windows eventlog"), FFI.errno)
    end
  end

  # Close this instance's event log handle
  # @return [void]
  # @api public
  def close
    DeregisterEventSource(@eventlog_handle)
  ensure
    @eventlog_handle = nil
  end

  # Report an event to this instance's event log handle. Accepts a string to
  #   report (:data => <string>) and event type (:event_type => FixNum) and id
  # (:event_id => FixNum) as returned by #to_native. The additional arguments to
  # ReportEventW seen in this method aren't exposed - though ReportEventW
  # technically can accept multiple strings as well as raw binary data to log,
  # we accept a single string from Puppet::Util::Log
  #
  # @param args [Hash{Symbol=>Object}] options to the associated log event
  # @return [void]
  # @api public
  def report_event(args = {})
    unless args[:data].is_a?(String)
      raise ArgumentError, _("data must be a string, not %{class_name}") % { class_name: args[:data].class }
    end
    from_string_to_wide_string(args[:data]) do |message_ptr|
      FFI::MemoryPointer.new(:pointer) do |message_array_ptr|
        message_array_ptr.write_pointer(message_ptr)
        user_sid = FFI::Pointer::NULL
        raw_data = FFI::Pointer::NULL
        raw_data_size = 0
        num_strings = 1
        eventlog_category = 0
        report_result = ReportEventW(@eventlog_handle, args[:event_type],
          eventlog_category, args[:event_id], user_sid,
          num_strings, raw_data_size, message_array_ptr, raw_data)

        if report_result == WIN32_FALSE
          #TRANSLATORS 'Windows' is the operating system and 'ReportEventW' is a API call and should not be translated
          raise EventLogError.new(_("ReportEventW failed to report event to Windows eventlog"), FFI.errno)
        end
      end
    end
  end

  class << self
    # Feels more natural to do Puppet::Util::Window::EventLog.open("MyApplication")
    alias :open :new

    # Query event identifier info for a given log level
    # @param level [Symbol] an event log level
    # @return [Array] Win API Event ID, Puppet Event ID
    # @api public
    def to_native(level)
      case level
      when :debug,:info,:notice
        [EVENTLOG_INFORMATION_TYPE, 0x01]
      when :warning
        [EVENTLOG_WARNING_TYPE, 0x02]
      when :err,:alert,:emerg,:crit
        [EVENTLOG_ERROR_TYPE, 0x03]
      else
        raise ArgumentError, _("Invalid log level %{level}") % { level: level }
      end
    end
  end

  private
  # For the purposes of allowing this class to be standalone, the following are
  # duplicate definitions from elsewhere in Puppet:

  # If we're loaded via Puppet we should keep the previous behavior of raising
  # Puppet::Util::Windows::Error on errors. If we aren't, at least concatenate
  # the error code to the exception message to pass this information on to the
  # user
  if defined?(Puppet::Util::Windows::Error)
    EventLogError = Puppet::Util::Windows::Error
  else
    class EventLogError < RuntimeError
      def initialize(msg, code)
        #TRANSLATORS 'Win32' is the Windows API and should not be translated
        super(msg + ' ' + _("(Win32 error: %{detail})") % { detail: code})
      end
    end
  end

  # Private duplicate of Puppet::Util::Windows::String::wide_string
  # Not for use outside of EventLog! - use Puppet::Util::Windows instead
  # @api private
  def wide_string(str)
    # if given a nil string, assume caller wants to pass a nil pointer to win32
    return nil if str.nil?
    # ruby (< 2.1) does not respect multibyte terminators, so it is possible
    # for a string to contain a single trailing null byte, followed by garbage
    # causing buffer overruns.
    #
    # See http://svn.ruby-lang.org/cgi-bin/viewvc.cgi?revision=41920&view=revision
    newstr = str + "\0".encode(str.encoding)
    newstr.encode!('UTF-16LE')
  end

  # Private duplicate of Puppet::Util::Windows::ApiTypes::from_string_to_wide_string
  # Not for use outside of EventLog! - Use Puppet::Util::Windows instead
  # @api private
  def from_string_to_wide_string(str, &block)
    str = wide_string(str)
    FFI::MemoryPointer.new(:uchar, str.bytesize) do |ptr|
      # uchar here is synonymous with byte
      ptr.put_array_of_uchar(0, str.bytes.to_a)

      yield ptr
    end

    # ptr has already had free called, so nothing to return
    nil
  end

  ffi_convention :stdcall

  # The following are typedefs in Puppet::Util::Winodws::ApiTypes, but here we
  # use their original FFI counterparts:
  # :uintptr_t for :handle
  # :int32 for :win32_bool
  # :uint16 for :word
  # :uint32 for :dword
  # :pointer for :lpvoid
  # :uchar for :byte

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa363678(v=vs.85).aspx
  # HANDLE RegisterEventSource(
  # _In_ LPCTSTR lpUNCServerName,
  # _In_ LPCTSTR lpSourceName
  # );
  ffi_lib :advapi32
  attach_function :RegisterEventSourceW, [:buffer_in, :buffer_in], :uintptr_t
  private :RegisterEventSourceW

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa363642(v=vs.85).aspx
  # BOOL DeregisterEventSource(
  # _Inout_ HANDLE hEventLog
  # );
  ffi_lib :advapi32
  attach_function :DeregisterEventSource, [:uintptr_t], :int32
  private :DeregisterEventSource

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa363679(v=vs.85).aspx
  # BOOL ReportEvent(
  #   _In_ HANDLE  hEventLog,
  #   _In_ WORD    wType,
  #   _In_ WORD    wCategory,
  #   _In_ DWORD   dwEventID,
  #   _In_ PSID    lpUserSid,
  #   _In_ WORD    wNumStrings,
  #   _In_ DWORD   dwDataSize,
  #   _In_ LPCTSTR *lpStrings,
  #   _In_ LPVOID  lpRawData
  # );
  ffi_lib :advapi32
  attach_function :ReportEventW, [:uintptr_t, :uint16, :uint16, :uint32, :pointer, :uint16, :uint32, :pointer, :pointer], :int32
  private :ReportEventW
end
