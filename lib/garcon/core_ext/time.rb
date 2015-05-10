# encoding: UTF-8
#
# Author:    Stefano Harding <riddopic@gmail.com>
# License:   Apache License, Version 2.0
# Copyright: (C) 2014-2015 Stefano Harding
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class Time
  # Tracks the elapse time of a code block.
  #
  # @example
  #   e = Time.elapse { sleep 1 }
  #   e.assert > 1
  #
  def self.elapse
    raise "you need to pass a block" unless block_given?
    t0 = now.to_f
    yield
    now.to_f - t0
  end

	# Return a float of time since linux epoch
	#
  # @example
	#   Time.time     -> 1295953427.0005338
	#
	# @return [Float]
  def self.time
    now.to_f
  end

  unless const_defined?('FORMAT')
    FORMAT = {
      utc:      '%Y-%m-%d %H:%M:%S',        # => 2015-04-19 14:03:59
      utcT:     '%Y-%m-%dT%H:%M:%S',        # => 2015-04-19T14:03:59
      db:       '%Y-%m-%d %H:%M:%S',        # => 2015-04-19 14:03:59
      database: '%Y-%m-%d %H:%M:%S',        # => 2015-04-19 14:03:59
      number:   '%Y%m%d%H%M%S',             # => 20150419140359
      short:    '%d %b %H:%M',              # => 19 Apr 14:
      time:     '%H:%M',                    # => 14:03
      long:     '%B %d, %Y %H:%M',          # => April 19, 2015 14:03
      day1st:   '%d-%m-%Y %H:%M',           # => 19-04-2015 14:03
      dmYHM:    '%d-%m-%Y %H:%M',           # => 19-04-2015 14:03
      rfc822:   '%a, %d %b %Y %H:%M:%S %z', # => Sun, 19 Apr 2015 14:03:59 -0700
      ruby18:   '%a %b %d %H:%M:%S %z %Y',  # => Sun Apr 19 14:03:59 -0700 2015
      nil    => '%Y-%m-%d %H:%M:%S %z'      # => 2015-04-19 14:03:59 -0700
    }
  end

  # Produce time stamp for Time.now. See #stamp.
  #
  def self.stamp(*args)
    now.stamp(*args)
  end

  # Create a time stamp.
  #
  # @example
  #   t = Time.at(10000)
  #   t.stamp(:short)    # => "31 Dec 21:46"
  #
  # Supported formats come from the Time::FORMAT constant.
  #
  def stamp(format = nil)
    unless String === format
      format = FORMAT[format]
    end
    strftime(format).strip
  end

  unless method_defined?(:dst_adjustment)
    # Adjust DST
    #
    def dst_adjustment(time)
      self_dst = self.dst? ? 1 : 0
      time_dst = time.dst? ? 1 : 0
      seconds  = (self - time).abs
      if (seconds >= 86400 && self_dst != time_dst)
        time + ((self_dst - time_dst) * 60 * 60)
      else
        time
      end
    end
  end

  # Like change but does not reset earlier times.
  #
  def set(options)
    opts={}
    options.each_pair do |k,v|
      k = :min if k.to_s =~ /^min/
      k = :sec if k.to_s =~ /^sec/
      opts[k] = v.to_i
    end
    self.class.send(
      self.utc? ? :utc : :local,
      opts[:year]  || self.year,
      opts[:month] || self.month,
      opts[:day]   || self.day,
      opts[:hour]  || self.hour,
      opts[:min]   || self.min,
      opts[:sec]   || self.sec,
      opts[:usec]  || self.usec
    )
  end

  # Returns a new Time representing the time shifted by the time-units given.
  # Positive number shift the time forward, negative number shift the time
  # backward.
  #
  # @example
  #   t = Time.utc(2010,10,10,0,0,0)
  #   t.shift( 4, :days)            # =>  Time.utc(2010,10,14,0,0,0)
  #   t.shift(-4, :days)            # =>  Time.utc(2010,10,6,0,0,0)
  #
  # More than one unit of time can be given.
  #   t.shift(4, :days, 3, :hours)  # =>  Time.utc(2010,10,14,3,0,0)
  #
  # The #shift method can also take a hash.
  #   t.shift(:days=>4, :hours=>3)  # =>  Time.utc(2010,10,14,3,0,0)
  #
  def shift(*time_units)
    time_hash = Hash===time_units.last ? time_units.pop : {}
    time_units = time_units.flatten
    time_units << :seconds if time_units.size % 2 == 1
    time_hash.each{ |units, number| time_units << number; time_units << units }

    time = self
    time_units.each_slice(2) do |number, units|
      #next time = time.ago(-number, units) if number < 0
      time = (
        case units.to_s.downcase.to_sym
        when :years, :year
          time.set( :year=>(year + number) )
        when :months, :month
          if number > 0
            new_month = ((month + number - 1) % 12) + 1
            y = (number / 12) + (new_month < month ? 1 : 0)
            time.set(:year => (year + y), :month => new_month)
          else
            number = -number
            new_month = ((month - number - 1) % 12) + 1
            y = (number / 12) + (new_month > month ? 1 : 0)
            time.set(:year => (year - y), :month => new_month)
          end
        when :weeks, :week
          time + (number * 604800)
        when :days, :day
          time + (number * 86400)
        when :hours, :hour
          time + (number * 3600)
        when :minutes, :minute, :mins, :min
          time + (number * 60)
        when :seconds, :second, :secs, :sec, nil
          time + number
        else
          raise ArgumentError, "unrecognized time units -- #{units}"
        end
      )
    end
    dst_adjustment(time)
  end

  # Alias for #shift.
  alias_method :in, :shift

  # Alias for #shift.
  alias_method :hence, :shift unless method_defined?(:hence)

  # Returns a new Time representing the time a number of time-units ago.
  # This is just like #shift, but reverses the direction.
  #
  # @example
  #   t = Time.utc(2010,10,10,0,0,0)
  #   t.less(4, :days)             # =>  Time.utc(2010,10,6,0,0,0)
  #
  def less(*time_units)
    time_hash  = Hash===time_units.last ? time_units.pop : {}
    time_units = time_units.flatten

    time_units << :seconds if time_units.size % 2 == 1

    time_hash.each{ |units, number| time_units << number; time_units << units }

    neg_times = []
    time_units.each_slice(2){ |number, units| neg_times << -number; neg_times << units }

    shift(*neg_times)
  end

  # Alias for #less
  alias_method :ago, :less unless method_defined?(:ago)
end

class Numeric
  # Reports the approximate distance in time between two Time, Date or DateTime
  # objects or integers as seconds.
  #
  # @example
  #   1.time_humanize(true)    -> 1 seconds
  #   36561906.time_humanize   -> 1 years 2 months 3 days 4 hours 5 minutes
  #
  def time_humanize(include_seconds = false)
    deta = self
    deta,  seconds = deta.divmod(60)
    deta,  minutes = deta.divmod(60)
    deta,  hours   = deta.divmod(24)
    deta,  days    = deta.divmod(30)
    years, months  = deta.divmod(12)

    ret  = ''
    ret << "#{years} years "     unless years   == 0
    ret << "#{months} months "   unless months  == 0
    ret << "#{days} days "       unless days    == 0
    ret << "#{hours} hours "     unless hours   == 0
    ret << "#{minutes} minutes " unless minutes == 0
    ret << "#{seconds} seconds"      if include_seconds

    ret.rstrip
  end
end
