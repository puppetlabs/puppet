# frozen_string_literal: true

require_relative '../../../puppet/ffi/windows'
require_relative '../../../puppet/util/windows/string'

module Puppet::FFI::Windows
  module APITypes
    module ::FFI
      WIN32_FALSE = 0

      # standard Win32 error codes
      ERROR_SUCCESS = 0
    end

    module ::FFI::Library
      # Wrapper method for attach_function + private
      def attach_function_private(*args)
        attach_function(*args)
        private args[0]
      end
    end

    class ::FFI::Pointer
      NULL_HANDLE = 0
      WCHAR_NULL = String.new("\0\0").force_encoding('UTF-16LE').freeze

      def self.from_string_to_wide_string(str, &block)
        str = Puppet::Util::Windows::String.wide_string(str)
        FFI::MemoryPointer.from_wide_string(str, &block)

        # ptr has already had free called, so nothing to return
        nil
      end

      def read_win32_bool
        # BOOL is always a 32-bit integer in Win32
        # some Win32 APIs return 1 for true, while others are non-0
        read_int32 != FFI::WIN32_FALSE
      end

      alias_method :read_dword, :read_uint32
      alias_method :read_win32_ulong, :read_uint32
      alias_method :read_qword, :read_uint64

      alias_method :read_hresult, :read_int32

      def read_handle
        type_size == 4 ? read_uint32 : read_uint64
      end

      alias_method :read_wchar, :read_uint16
      alias_method :read_word,  :read_uint16
      alias_method :read_array_of_wchar, :read_array_of_uint16

      def read_wide_string(char_length, dst_encoding = Encoding::UTF_8, strip = false, encode_options = {})
        # char_length is number of wide chars (typically excluding NULLs), *not* bytes
        str = get_bytes(0, char_length * 2).force_encoding('UTF-16LE')

        if strip
          i = str.index(WCHAR_NULL)
          str = str[0, i] if i
        end

        str.encode(dst_encoding, str.encoding, **encode_options)
      rescue EncodingError => e
        Puppet.debug { "Unable to convert value #{str.nil? ? 'nil' : str.dump} to encoding #{dst_encoding} due to #{e.inspect}" }
        raise
      end

      # @param max_char_length [Integer] Maximum number of wide chars to return (typically excluding NULLs), *not* bytes
      # @param null_terminator [Symbol] Number of number of null wchar characters, *not* bytes, that determine the end of the string
      #   null_terminator = :single_null, then the terminating sequence is two bytes of zero.   This is UNIT16 = 0
      #   null_terminator = :double_null, then the terminating sequence is four bytes of zero.  This is UNIT32 = 0
      # @param encode_options [Hash] Accepts the same option hash that may be passed to String#encode in Ruby
      def read_arbitrary_wide_string_up_to(max_char_length = 512, null_terminator = :single_null, encode_options = {})
        idx = case null_terminator
              when :single_null
                # find index of wide null between 0 and max (exclusive)
                (0...max_char_length).find do |i|
                  get_uint16(i * 2) == 0
                end
              when :double_null
                # find index of double-wide null between 0 and max - 1 (exclusive)
                (0...max_char_length - 1).find do |i|
                  get_uint32(i * 2) == 0
                end
              else
                raise _("Unable to read wide strings with %{null_terminator} terminal nulls") % { null_terminator: null_terminator }
              end

        read_wide_string(idx || max_char_length, Encoding::UTF_8, false, encode_options)
      end

      def read_win32_local_pointer(&block)
        ptr = read_pointer
        begin
          yield ptr
        ensure
          if !ptr.null? && FFI::WIN32::LocalFree(ptr.address) != FFI::Pointer::NULL_HANDLE
            Puppet.debug "LocalFree memory leak"
          end
        end

        # ptr has already had LocalFree called, so nothing to return
        nil
      end

      def read_com_memory_pointer(&block)
        ptr = read_pointer
        begin
          yield ptr
        ensure
          FFI::WIN32::CoTaskMemFree(ptr) unless ptr.null?
        end

        # ptr has already had CoTaskMemFree called, so nothing to return
        nil
      end

      alias_method :write_dword, :write_uint32
      alias_method :write_word, :write_uint16
    end

    class FFI::MemoryPointer
      # Return a MemoryPointer that points to wide string. This is analogous to the
      # FFI::MemoryPointer.from_string method.
      def self.from_wide_string(wstr)
        ptr = FFI::MemoryPointer.new(:uchar, wstr.bytesize + 2)
        ptr.put_array_of_uchar(0, wstr.bytes.to_a)
        ptr.put_uint16(wstr.bytesize, 0)

        yield ptr if block_given?

        ptr
      end
    end

    # FFI Types
    # https://github.com/ffi/ffi/wiki/Types

    # Windows - Common Data Types
    # https://msdn.microsoft.com/en-us/library/cc230309.aspx

    # Windows Data Types
    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa383751(v=vs.85).aspx

    FFI.typedef :uint16, :word
    FFI.typedef :uint32, :dword
    # uintptr_t is defined in an FFI conf as platform specific, either
    # ulong_long on x64 or just ulong on x86
    FFI.typedef :uintptr_t, :handle
    FFI.typedef :uintptr_t, :hwnd

    # buffer_inout is similar to pointer (platform specific), but optimized for buffers
    FFI.typedef :buffer_inout, :lpwstr
    # buffer_in is similar to pointer (platform specific), but optimized for CONST read only buffers
    FFI.typedef :buffer_in, :lpcwstr
    FFI.typedef :buffer_in, :lpcolestr

    # string is also similar to pointer, but should be used for const char *
    # NOTE that this is not wide, useful only for A suffixed functions
    FFI.typedef :string, :lpcstr

    # pointer in FFI is platform specific
    # NOTE: for API calls with reserved lpvoid parameters, pass a FFI::Pointer::NULL
    FFI.typedef :pointer, :lpcvoid
    FFI.typedef :pointer, :lpvoid
    FFI.typedef :pointer, :lpword
    FFI.typedef :pointer, :lpbyte
    FFI.typedef :pointer, :lpdword
    FFI.typedef :pointer, :pdword
    FFI.typedef :pointer, :phandle
    FFI.typedef :pointer, :ulong_ptr
    FFI.typedef :pointer, :pbool
    FFI.typedef :pointer, :lpunknown

    # any time LONG / ULONG is in a win32 API definition DO NOT USE platform specific width
    # which is what FFI uses by default
    # instead create new aliases for these very special cases
    # NOTE: not a good idea to redefine FFI :ulong since other typedefs may rely on it
    FFI.typedef :uint32, :win32_ulong
    FFI.typedef :int32, :win32_long
    # FFI bool can be only 1 byte at times,
    # Win32 BOOL is a signed int, and is always 4 bytes, even on x64
    # https://blogs.msdn.com/b/oldnewthing/archive/2011/03/28/10146459.aspx
    FFI.typedef :int32, :win32_bool

    # BOOLEAN (unlike BOOL) is a BYTE - typedef unsigned char BYTE;
    FFI.typedef :uchar, :boolean

    # Same as a LONG, a 32-bit signed integer
    FFI.typedef :int32, :hresult

    # NOTE: FFI already defines (u)short as a 16-bit (un)signed like this:
    # FFI.typedef :uint16, :ushort
    # FFI.typedef :int16, :short

    # 8 bits per byte
    FFI.typedef :uchar, :byte
    FFI.typedef :uint16, :wchar

    # Definitions for data types used in LSA structures and functions
    # https://docs.microsoft.com/en-us/windows/win32/api/ntsecapi/
    # https://docs.microsoft.com/sr-latn-rs/windows/win32/secmgmt/management-data-types
    FFI.typedef :pointer, :pwstr
    FFI.typedef :pointer, :pulong
    FFI.typedef :pointer, :lsa_handle
    FFI.typedef :pointer, :plsa_handle
    FFI.typedef :pointer, :psid
    FFI.typedef :pointer, :pvoid
    FFI.typedef :pointer, :plsa_unicode_string
    FFI.typedef :pointer, :plsa_object_attributes
    FFI.typedef :uint32,  :ntstatus
    FFI.typedef :dword,   :access_mask

    module ::FFI::WIN32
      extend ::FFI::Library

      # https://msdn.microsoft.com/en-us/library/windows/desktop/aa373931(v=vs.85).aspx
      # typedef struct _GUID {
      #   DWORD Data1;
      #   WORD  Data2;
      #   WORD  Data3;
      #   BYTE  Data4[8];
      # } GUID;
      class GUID < FFI::Struct
        layout :Data1, :dword,
               :Data2, :word,
               :Data3, :word,
               :Data4, [:byte, 8]

        def self.[](s)
          raise _('Bad GUID format.') unless s =~ /^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$/i

          new.tap do |guid|
            guid[:Data1] = s[0, 8].to_i(16)
            guid[:Data2] = s[9, 4].to_i(16)
            guid[:Data3] = s[14, 4].to_i(16)
            guid[:Data4][0] = s[19, 2].to_i(16)
            guid[:Data4][1] = s[21, 2].to_i(16)
            s[24, 12].split('').each_slice(2).with_index do |a, i|
              guid[:Data4][i + 2] = a.join('').to_i(16)
            end
          end
        end

        def ==(other) Windows.memcmp(other, self, size) == 0 end
      end

      # https://msdn.microsoft.com/en-us/library/windows/desktop/ms724950(v=vs.85).aspx
      # typedef struct _SYSTEMTIME {
      #   WORD wYear;
      #   WORD wMonth;
      #   WORD wDayOfWeek;
      #   WORD wDay;
      #   WORD wHour;
      #   WORD wMinute;
      #   WORD wSecond;
      #   WORD wMilliseconds;
      # } SYSTEMTIME, *PSYSTEMTIME;
      class SYSTEMTIME < FFI::Struct
        layout :wYear, :word,
               :wMonth, :word,
               :wDayOfWeek, :word,
               :wDay, :word,
               :wHour, :word,
               :wMinute, :word,
               :wSecond, :word,
               :wMilliseconds, :word

        def to_local_time
          Time.local(self[:wYear], self[:wMonth], self[:wDay],
                     self[:wHour], self[:wMinute], self[:wSecond], self[:wMilliseconds] * 1000)
        end
      end

      # https://msdn.microsoft.com/en-us/library/windows/desktop/ms724284(v=vs.85).aspx
      # Contains a 64-bit value representing the number of 100-nanosecond
      # intervals since January 1, 1601 (UTC).
      # typedef struct _FILETIME {
      #   DWORD dwLowDateTime;
      #   DWORD dwHighDateTime;
      # } FILETIME, *PFILETIME;
      class FILETIME < FFI::Struct
        layout :dwLowDateTime, :dword,
               :dwHighDateTime, :dword
      end

      ffi_convention :stdcall

      # https://msdn.microsoft.com/en-us/library/windows/desktop/aa366730(v=vs.85).aspx
      # HLOCAL WINAPI LocalFree(
      #   _In_  HLOCAL hMem
      # );
      ffi_lib :kernel32
      attach_function :LocalFree, [:handle], :handle

      # https://msdn.microsoft.com/en-us/library/windows/desktop/ms724211(v=vs.85).aspx
      # BOOL WINAPI CloseHandle(
      #   _In_  HANDLE hObject
      # );
      ffi_lib :kernel32
      attach_function_private :CloseHandle, [:handle], :win32_bool

      # https://msdn.microsoft.com/en-us/library/windows/desktop/ms680722(v=vs.85).aspx
      # void CoTaskMemFree(
      #   _In_opt_  LPVOID pv
      # );
      ffi_lib :ole32
      attach_function :CoTaskMemFree, [:lpvoid], :void
    end
  end
end
