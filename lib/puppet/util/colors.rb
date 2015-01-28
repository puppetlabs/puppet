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

  def colorize(color, str)
    case Puppet[:color]
    when true, :ansi, "ansi", "yes"
        console_color(color, str)
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
