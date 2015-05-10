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

class String
  # Get or set state of object. You can think of #object_state as an in-code
  # form of marshalling.
  #
  def object_state(data = nil)
    data ? replace(data) : dup
  end

  # Common Unix cryptography method. This adds a default salt to the built-in
  # crypt method.
  #
  def crypt(salt = nil)
    salt ||= ((SecureRandom.random_number(26) +
              (SecureRandom.random_number(2) == 0 ? 65 : 97)).chr +
              (SecureRandom.random_number(26) +
              (SecureRandom.random_number(2) == 0 ? 65 : 97)).chr)
    _crypt(salt)
  end

  # Search a text file for a matching string
  #
  # @return [Boolean]
  #   True if the file is present and a match was found, otherwise returns
  #   false if file does not exist and/or does not contain a match
  #
  # @api public
  def contains?(str)
    return false unless ::File.exist?(self)
    ::File.open(self, &:readlines).collect { |l| return true if l.match(str) }
    false
  end

  # Turns a string into a regular expression.
  #
  #   "a?".to_re  #=> /a?/
  #
  def to_re(esc = false)
    Regexp.new((esc ? Regexp.escape(self) : self))
  end

  # Turns a string into a regular expression.
  # By default it will escape all characters.
  # Use <tt>false</tt> argument to turn off escaping.
  #
  #   "[".to_rx  #=> /\[/
  #
  def to_rx(esc = true)
    Regexp.new((esc ? Regexp.escape(self) : self))
  end

  # Strips out whitespace then tests if the string is empty.
  #
  #   "".blank?         #=>  true
  #   "     ".blank?    #=>  true
  #   " hey ho ".blank? #=>  false
  #
  # @return [Boolean]
  #
  def blank?
    strip.empty?
  end

  # Breaks a string up into an array based on a regular expression.
  # Similar to scan, but includes the matches.
  #
  # @example
  #   s = "<p>This<b>is</b>a test.</p>"
  #   s.shatter(/\<.*?\>/)
  #     => [
  #       [0] "<p>",
  #       [1] "This",
  #       [2] "<b>",
  #       [3] "is",
  #       [4] "</b>",
  #       [5] "a test.",
  #       [6] "</p>"
  #     ]
  #
  # @param [Regexp] regex
  #   Regular expression for breaking string into array.
  #
  # @return [String]
  #
  # @api public
  def shatter(re)
    r = self.gsub(re) { |s| "\1" + s + "\1" }
    while r[ 0, 1] == "\1";  r[0] = ''; end
    while r[-1, 1] == "\1"; r[-1] = ''; end
    r.split("\1")
  end

  # Left-flush a string based off of the number of whitespace characters on the
  # first line. This is especially useful for heredocs when whitespace matters.
  #
  # @example Remove leading whitespace and flush
  #   <<-EOH.flush
  #     def method
  #       'This is a string!'
  #     end
  #   EOH # =>"def method\n  'This is a string!'\nend"
  #
  # @return [String]
  #
  # @api public
  def flush
    gsub(/^#{self[/\A\s*/]}/, '').chomp
  end unless method_defined?(:flush)

  # Escape all regexp special characters.
  #
  # @example
  #   "*?{}.".escape_regexp   # => "\\*\\?\\{\\}\\."
  #
  # @return [String]
  #   Receiver with all regexp special characters escaped.
  #
  # @api public
  def escape_regexp
    Regexp.escape self
  end

  # Unescape all regexp special characters.
  #
  # @example
  #   "\\*\\?\\{\\}\\.".unescape_regexp # => "*?{}."
  #
  # @return [String]
  #   Receiver with all regexp special characters unescaped.
  #
  # @api public
  def unescape_regexp
    self.gsub(/\\([\.\?\|\(\)\[\]\{\}\^\$\*\+\-])/, '\1')
  end

  # Convert a path string to a constant name.
  #
  # @example
  #   "chef/mixin/checksum".to_const_string # => "Chef::Mixin::Checksum"
  #
  # @return [String]
  #   Receiver converted to a constant name.
  #
  # @api public
  def to_const_string
    gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase }
  end

  # Convert a constant name to a path, assuming a conventional structure.
  #
  # @example
  #   "FooBar::Baz".to_const_path # => "foo_bar/baz"
  #
  # @return [String]
  #   Path to the file containing the constant named by receiver (constantized
  #   string), assuming a conventional structure.
  #
  # @api public
  def to_const_path
    snake_case.gsub(/::/, "/")
  end

  # Join with _o_ as a file path.
  #
  # @example
  #   'usr'/'local' # => 'usr/local'
  #
  # @param [String] other
  #   Path component(s) to join with receiver.
  #
  # @return [String]
  #   Receiver joined with other as a file path.
  #
  # @api public
  def /(other)
    File.join(self, other.to_s)
  end

  # Calculate a relative path *from* _other_.
  #
  # @example
  #   '/opt/chefdk/'.relative_path_from '/opt/chefdk/embedded/bin' # => '../..'
  #
  # @param [String] other
  #   Base path to calculate *from*.
  #
  # @return [String]
  #   Relative path from _other_ to receiver.
  #
  # @api public
  def relative_path_from(other)
    Pathname.new(self).relative_path_from(Pathname.new(other)).to_s
  end

  # Replace sequences of whitespace (including newlines) with either
  # a single space or remove them entirely (according to param _spaced_)
  #
  # @example
  #   <<QUERY.compress_lines
  #     SELECT name
  #     FROM users
  #   QUERY => 'SELECT name FROM users'
  #
  # @param [Boolean] spaced (default=true)
  #   Determines whether returned string has whitespace collapsed or removed
  #
  # @return [String]
  #   Receiver with whitespace (including newlines) replaced
  #
  # @api public
  def compress_lines(spaced = true)
    split($/).map { |line| line.strip }.join(spaced ? ' ' : '')
  end

  # Remove whitespace margin.
  #
  # @return [String]
  #   Receiver with whitespace margin removed.
  #
  # @api public
  def margin(indicator = nil)
    lines = self.dup.split($/)

    min_margin = 0
    lines.each do |line|
      if line =~ /^(\s+)/ && (min_margin == 0 || $1.size < min_margin)
        min_margin = $1.size
      end
    end
    lines.map { |line| line.sub(/^\s{#{min_margin}}/, '') }.join($/)
  end

  # Formats String for easy translation. Replaces an arbitrary number of
  # values using numeric identifier replacement.
  #
  # @example
  #   "%s %s %s" % %w(one two three)        # => 'one two three'
  #   "%3$s %2$s %1$s" % %w(one two three)  # => 'three two one'
  #
  # @param [#to_s] values
  #   A list of values to translate and interpolate into receiver
  #
  # @return [String]
  #   Receiver translated with values translated and interpolated positionally
  #
  # @api public
  def t(*values)
    self.class::translate(self) % values.collect! do |value|
      value.frozen? ? value : self.class::translate(value.to_s)
    end
  end

  def clear;      colorize(self, "\e[0m");    end
  def erase_line; colorize(self, "\e[K");     end
  def erase_char; colorize(self, "\e[P");     end
  def bold;       colorize(self, "\e[1m");    end
  def dark;       colorize(self, "\e[2m");    end
  def underline;  colorize(self, "\e[4m");    end
  def blink;      colorize(self, "\e[5m");    end
  def reverse;    colorize(self, "\e[7m");    end
  def concealed;  colorize(self, "\e[8m");    end
  def black;      colorize(self, "\e[0;30m"); end
  def gray;       colorize(self, "\e[1;30m"); end
  def red;        colorize(self, "\e[0;31m"); end
  def magenta;    colorize(self, "\e[1;31m"); end
  def green;      colorize(self, "\e[0;32m"); end
  def olive;      colorize(self, "\e[1;32m"); end
  def yellow;     colorize(self, "\e[0;33m"); end
  def cream;      colorize(self, "\e[1;33m"); end
  def blue;       colorize(self, "\e[0;34m"); end
  def purple;     colorize(self, "\e[1;34m"); end
  def orange;     colorize(self, "\e[0;35m"); end
  def mustard;    colorize(self, "\e[1;35m"); end
  def cyan;       colorize(self, "\e[0;36m"); end
  def cyan2;      colorize(self, "\e[1;36m"); end
  def light_gray; colorize(self, "\e[2;37m"); end
  def bright_red; colorize(self, "\e[1;41m"); end
  def white;      colorize(self, "\e[0;97m"); end
  def on_black;   colorize(self, "\e[40m");   end
  def on_red;     colorize(self, "\e[41m");   end
  def on_green;   colorize(self, "\e[42m");   end
  def on_yellow;  colorize(self, "\e[43m");   end
  def on_blue;    colorize(self, "\e[44m");   end
  def on_magenta; colorize(self, "\e[45m");   end
  def on_cyan;    colorize(self, "\e[46m");   end
  def on_white;   colorize(self, "\e[47m");   end
  def colorize(text, color_code) "#{color_code}#{text}\e[0m" end
end
