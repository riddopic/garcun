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

  # Clock that cannot be set and represents monotonic time since
  # some unspecified starting point.
  # @!visibility private
  GLOBAL_MONOTONIC_CLOCK = Class.new {

    if defined?(Process::CLOCK_MONOTONIC)
      # @!visibility private
      def get_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    else

      require 'thread'

      # @!visibility private
      def initialize
        @mutex      = Mutex.new
        @last_time  = Time.now.to_f
      end

      # @!visibility private
      def get_time
        @mutex.synchronize do
          now = Time.now.to_f
          if @last_time < now
            @last_time = now
          else # clock has moved back in time
            @last_time +=  0.000_001
          end
        end
      end
    end
  }.new
  private_constant :GLOBAL_MONOTONIC_CLOCK

  # @!macro [attach] monotonic_get_time
  #
  #   Returns the current time a tracked by the application monotonic clock.
  #
  #   @return [Float] The current monotonic time when `since` not given else
  #     the elapsed monotonic time between `since` and the current time
  #
  #   @!macro monotonic_clock_warning
  def monotonic_time
    GLOBAL_MONOTONIC_CLOCK.get_time
  end
  module_function :monotonic_time
end
