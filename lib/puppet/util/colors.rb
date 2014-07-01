require 'puppet/util/platform'

module Puppet::Util::Colors
  BLACK       = {:console => "\e[0;30m", :html => "color: #FFA0A0"     }
  RED         = {:console => "\e[0;31m", :html => "color: #FFA0A0"     }
  GREEN       = {:console => "\e[0;32m", :html => "color: #00CD00"     }
  YELLOW      = {:console => "\e[0;33m", :html => "color: #FFFF60"     }
  BLUE        = {:console => "\e[0;34m", :html => "color: #80A0FF"     }
  MAGENTA     = {:console => "\e[0;35m", :html => "color: #FFA500"     }
  CYAN        = {:console => "\e[0;36m", :html => "color: #40FFFF"     }
  WHITE       = {:console => "\e[0;37m", :html => "color: #FFFFFF"     }
  HBLACK      = {:console => "\e[1;30m", :html => "color: #FFA0A0"     }
  HRED        = {:console => "\e[1;31m", :html => "color: #FFA0A0"     }
  HGREEN      = {:console => "\e[1;32m", :html => "color: #00CD00"     }
  HYELLOW     = {:console => "\e[1;33m", :html => "color: #FFFF60"     }
  HBLUE       = {:console => "\e[1;34m", :html => "color: #80A0FF"     }
  HMAGENTA    = {:console => "\e[1;35m", :html => "color: #FFA500"     }
  HCYAN       = {:console => "\e[1;36m", :html => "color: #40FFFF"     }
  HWHITE      = {:console => "\e[1;37m", :html => "color: #FFFFFF"     }
  BG_RED      = {:console => "\e[0;41m", :html => "background: #FFA0A0"}
  BG_GREEN    = {:console => "\e[0;42m", :html => "background: #00CD00"}
  BG_YELLOW   = {:console => "\e[0;43m", :html => "background: #FFFF60"}
  BG_BLUE     = {:console => "\e[0;44m", :html => "background: #80A0FF"}
  BG_MAGENTA  = {:console => "\e[0;45m", :html => "background: #FFA500"}
  BG_CYAN     = {:console => "\e[0;46m", :html => "background: #40FFFF"}
  BG_WHITE    = {:console => "\e[0;47m", :html => "background: #FFFFFF"}
  BG_HRED     = {:console => "\e[1;41m", :html => "background: #FFA0A0"}
  BG_HGREEN   = {:console => "\e[1;42m", :html => "background: #00CD00"}
  BG_HYELLOW  = {:console => "\e[1;43m", :html => "background: #FFFF60"}
  BG_HBLUE    = {:console => "\e[1;44m", :html => "background: #80A0FF"}
  BG_HMAGENTA = {:console => "\e[1;45m", :html => "background: #FFA500"}
  BG_HCYAN    = {:console => "\e[1;46m", :html => "background: #40FFFF"}
  BG_HWHITE   = {:console => "\e[1;47m", :html => "background: #FFFFFF"}
  RESET       = {:console => "\e[0m",    :html => ""                   }

  Colormap = {
    :debug => WHITE,
    :info => GREEN,
    :notice => CYAN,
    :warning => YELLOW,
    :err => HMAGENTA,
    :alert => RED,
    :emerg => HRED,
    :crit => HRED,

    :black       => BLACK,
    :red         => RED,
    :green       => GREEN,
    :yellow      => YELLOW,
    :blue        => BLUE,
    :magenta     => MAGENTA,
    :cyan        => CYAN,
    :white       => WHITE,
    :hblack      => HBLACK,
    :hred        => HRED,
    :hgreen      => HGREEN,
    :hyellow     => HYELLOW,
    :hblue       => HBLUE,
    :hmagenta    => HMAGENTA,
    :hcyan       => HCYAN,
    :hwhite      => HWHITE,
    :bg_red      => BG_RED,
    :bg_green    => BG_GREEN,
    :bg_yellow   => BG_YELLOW,
    :bg_blue     => BG_BLUE,
    :bg_magenta  => BG_MAGENTA,
    :bg_cyan     => BG_CYAN,
    :bg_white    => BG_WHITE,
    :bg_hred     => BG_HRED,
    :bg_hgreen   => BG_HGREEN,
    :bg_hyellow  => BG_HYELLOW,
    :bg_hblue    => BG_HBLUE,
    :bg_hmagenta => BG_HMAGENTA,
    :bg_hcyan    => BG_HCYAN,
    :bg_hwhite   => BG_HWHITE,
    :reset       => { :console => "\e[m", :html => "" }
  }

  # We define console_has_color? at load time since it's checking the
  # underlying platform which will not change, and we don't want to perform
  # the check every time we use logging
  if Puppet::Util::Platform.windows? && RUBY_VERSION =~ /^1\./
    # We're on windows and using ruby less than v2
    # so we need win32console for color to work
    begin
      require 'ffi'
      require 'win32console'

      # The win32console gem uses ANSI functions for writing to the console
      # which doesn't work for unicode strings, e.g. module tool. Ruby 1.9
      # does the same thing, but doesn't account for ANSI escape sequences
      class WideConsole < Win32::Console
        extend FFI::Library

        # http://msdn.microsoft.com/en-us/library/windows/desktop/ms687401(v=vs.85).aspx
        # BOOL WINAPI WriteConsole(
        #   _In_        HANDLE hConsoleOutput,
        #   _In_        const VOID *lpBuffer,
        #   _In_        DWORD nNumberOfCharsToWrite,
        #   _Out_       LPDWORD lpNumberOfCharsWritten,
        #   _Reserved_  LPVOID lpReserved
        # );
        ffi_lib :kernel32
        attach_function_private :WriteConsoleW,
          [:handle, :lpcwstr, :dword, :lpdword, :lpvoid], :win32_bool

        # typedef struct _COORD {
        #   SHORT X;
        #   SHORT Y;
        # } COORD, *PCOORD;
        class COORD < FFI::Struct
          layout :X, :short,
                 :Y, :short
        end

        # http://msdn.microsoft.com/en-us/library/windows/desktop/ms687410(v=vs.85).aspx
        # BOOL WINAPI WriteConsoleOutputCharacter(
        #   _In_   HANDLE hConsoleOutput,
        #   _In_   LPCTSTR lpCharacter,
        #   _In_   DWORD nLength,
        #   _In_   COORD dwWriteCoord,
        #   _Out_  LPDWORD lpNumberOfCharsWritten
        # );
        ffi_lib :kernel32
        attach_function_private :WriteConsoleOutputCharacterW,
          [:handle, :lpcwstr, :dword, COORD, :lpdword], :win32_bool

        def initialize(t = nil)
          super(t)
        end

        def WriteChar(str, col, row)
          writeCoord = COORD.new()
          writeCoord[:X] = row
          writeCoord[:Y] = col

          chars_written = 0
          FFI::MemoryPointer.from_string_to_wide_string(str) do |msg_ptr|
            FFI::MemoryPointer.new(:dword, 1) do |numberOfCharsWritten_ptr|
              WriteConsoleOutputCharacterW(@handle, msg_ptr,
                str.length, writeCoord, numberOfCharsWritten_ptr)
              chars_written = numberOfCharsWritten_ptr.read_dword
            end
          end

          chars_written
        end

        def Write(str)
          result = false
          FFI::MemoryPointer.from_string_to_wide_string(str) do |msg_ptr|
            FFI::MemoryPointer.new(:dword, 1) do |numberOfCharsWritten_ptr|
              result = WriteConsoleW(@handle, msg_ptr,
                str.length, FFI::MemoryPointer.new(:dword, 1),
                FFI::MemoryPointer::NULL) != FFI::WIN32_FALSE
            end
          end

          result
        end
      end

      # Override the win32console's IO class so we can supply
      # our own Console class
      class WideIO < Win32::Console::ANSI::IO
        def initialize(fd_std = :stdout)
          super(fd_std)

          handle = FD_STD_MAP[fd_std][1]
          @Out = WideConsole.new(handle)
        end
      end

      $stdout = WideIO.new(:stdout)
      $stderr = WideIO.new(:stderr)
    rescue LoadError
      def console_has_color?
        false
      end
    else
      def console_has_color?
        true
      end
    end
  else
    # On a posix system we can just enable it
    def console_has_color?
      true
    end
  end

  def colorize(color, str)
    case Puppet[:color]
    when true, :ansi, "ansi", "yes"
      if console_has_color?
        console_color(color, str)
      else
        str
      end
    when :html, "html"
      html_color(color, str)
    else
      str
    end
  end

  def console_color(color, str)
    Colormap[color][:console] +
    str.gsub(RESET[:console], Colormap[color][:console]) +
    RESET[:console]
  end

  def html_color(color, str)
    span = '<span style="%s">' % Colormap[color][:html]
    "#{span}%s</span>" % str.gsub(/<span .*?<\/span>/, "</span>\\0#{span}")
  end
end
