# = progressbar.rb
#
# == Copyright (C) 2001 Satoru Takabayashi
#
#   Ruby License
#
#   This module is free software. You may use, modify, and/or redistribute this
#   software under the same terms as Ruby.
#
#   This program is distributed in the hope that it will be useful, but WITHOUT
#   ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
#   FOR A PARTICULAR PURPOSE.
#
# == Author(s)
#
# * Satoru Takabayashi

# Author::    Satoru Takabayashi
# Copyright:: Copyright (c) 2001 Satoru Takabayashi
# License::   Ruby License

# = Console Progress Bar
#
# Console::ProgressBar is a terminal-based progress bar library.
#
# == Usage
#
#   pbar = ConsoleProgressBar.new( "Demo", 100 )
#   100.times { pbar.inc }
#   pbar.finish
#

module Console; end

class Console::ProgressBar

  def initialize(title, total, out = STDERR)
    @title = title
    @total = total
    @out = out
    @bar_length = 80
    @bar_mark = "o"
    @total_overflow = true
    @current = 0
    @previous = 0
    @is_finished = false
    @start_time = Time.now
    @format = "%-14s %3d%% %s %s"
    @format_arguments = [:title, :percentage, :bar, :stat]
    show_progress
  end

  private
  def convert_bytes (bytes)
    if bytes < 1024
      sprintf("%6dB", bytes)
    elsif bytes < 1024 * 1000 # 1000kb
      sprintf("%5.1fKB", bytes.to_f / 1024)
    elsif bytes < 1024 * 1024 * 1000  # 1000mb
      sprintf("%5.1fMB", bytes.to_f / 1024 / 1024)
    else
      sprintf("%5.1fGB", bytes.to_f / 1024 / 1024 / 1024)
    end
  end

  def transfer_rate
    bytes_per_second = @current.to_f / (Time.now - @start_time)
    sprintf("%s/s", convert_bytes(bytes_per_second))
  end

  def bytes
    convert_bytes(@current)
  end

  def format_time (t)
    t = t.to_i
    sec = t % 60
    min  = (t / 60) % 60
    hour = t / 3600
    sprintf("%02d:%02d:%02d", hour, min, sec);
  end

  # ETA stands for Estimated Time of Arrival.
  def eta
    if @current == 0
      "ETA:  --:--:--"
    else
      elapsed = Time.now - @start_time
      eta = elapsed * @total / @current - elapsed;
      sprintf("ETA:  %s", format_time(eta))
    end
  end

  def elapsed
    elapsed = Time.now - @start_time
    sprintf("Time: %s", format_time(elapsed))
  end

  def stat
    if @is_finished then elapsed else eta end
  end

  def stat_for_file_transfer
    if @is_finished then 
      sprintf("%s %s %s", bytes, transfer_rate, elapsed)
    else 
      sprintf("%s %s %s", bytes, transfer_rate, eta)
    end
  end

  def eol
    if @is_finished then "\n" else "\r" end
  end

  def bar
    len = percentage * @bar_length / 100
    sprintf("|%s%s|", @bar_mark * len, " " *  (@bar_length - len))
  end

  def percentage
    if @total.zero?
      100
    else
      @current  * 100 / @total
    end
  end

  def title
    @title[0,13] + ":"
  end

  def get_width
    # FIXME: I don't know how portable it is.
    default_width = 80
    begin
      tiocgwinsz = 0x5413
      data = [0, 0, 0, 0].pack("SSSS")
      if @out.ioctl(tiocgwinsz, data) >= 0 then
        rows, cols, xpixels, ypixels = data.unpack("SSSS")
        if cols >= 0 then cols else default_width end
      else
        default_width
      end
    rescue Exception
      default_width
    end
  end

  def show
    arguments = @format_arguments.map {|method| send(method) }
    line = sprintf(@format, *arguments)

    width = get_width
    if line.length == width - 1 
      @out.print(line + eol)
    elsif line.length >= width
      @bar_length = [@bar_length - (line.length - width + 1), 0].max
      if @bar_length == 0 then @out.print(line + eol) else show end
    else #line.length < width - 1
      @bar_length += width - line.length + 1
      show
    end
  end

  def show_progress
    if @total.zero?
      cur_percentage = 100
      prev_percentage = 0
    else
      cur_percentage  = (@current  * 100 / @total).to_i
      prev_percentage = (@previous * 100 / @total).to_i
    end

    if cur_percentage > prev_percentage || @is_finished
      show
    end
  end

  public
  def file_transfer_mode
    @format_arguments = [:title, :percentage, :bar, :stat_for_file_transfer]  
  end

  def bar_mark= (mark)
    @bar_mark = String(mark)[0..0]
  end

  def total_overflow= (boolv)
    @total_overflow = boolv ? true : false
  end

  def format= (format)
    @format = format
  end

  def format_arguments= (arguments)
    @format_arguments = arguments
  end

  def finish
    @current = @total
    @is_finished = true
    show_progress
  end

  def halt
    @is_finished = true
    show_progress
  end

  def set (count)
    if count < 0
      raise "invalid count less than zero: #{count}"
    elsif count > @total
      if @total_overflow
        @total = count + 1
      else
        raise "invalid count greater than total: #{count}"
      end
    end
    @current = count
    show_progress
    @previous = @current
  end

  def inc (step = 1)
    @current += step
    @current = @total if @current > @total
    show_progress
    @previous = @current
  end

  def inspect
    "(ProgressBar: #{@current}/#{@total})"
  end

end
