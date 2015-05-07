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

module Garcon
  # Returns the columns and lines of the current tty.
  #
  # @return [Integer]
  #   Number of columns and lines of tty, returns [0, 0] if no tty is present.
  #
  def terminal_dimensions
    [0, 0] unless  STDOUT.tty?
    [80, 40] if OS.windows?

    if ENV['COLUMNS'] && ENV['LINES']
      [ENV['COLUMNS'].to_i, ENV['LINES'].to_i]
    elsif ENV['TERM'] && command_in_path?('tput')
      [`tput cols`.to_i, `tput lines`.to_i]
    elsif command_in_path?('stty')
      `stty size`.scan(/\d+/).map {|s| s.to_i }
    else
      [0, 0]
    end
  rescue
    [0, 0]
  end
end

class GarconHash < Hash
  def method_missing(method_name, *args)
    return super unless respond_to?(method_name)
    self[method_name].to_s
  end

  def respond_to?(symbol, include_private=false)
    return true if key?(symbol.to_s)
    super
  end
end
