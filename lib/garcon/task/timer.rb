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

require 'thread'

module Garcon

  # Perform the given operation asynchronously after the given number of
  # seconds.
  #
  # @param [Fixnum] seconds
  #   The interval in seconds to wait before executing the task
  #
  # @yield the task to execute
  #
  # @return [Boolean] true
  #
  def timer(seconds, *args, &block)
    raise ArgumentError, 'no block given' unless block_given?
    if seconds < 0
      raise ArgumentError, 'interval must be greater than or equal to zero'
    end

    Garcon.global_timer_set.post(seconds, *args, &block)
    true
  end
  module_function :timer
end
