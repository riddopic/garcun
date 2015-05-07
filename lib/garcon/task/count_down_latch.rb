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

require_relative 'condition'

module Garcon

  # A synchronization object that allows one thread to wait on multiple other
  # threads. The thread that will wait creates a `CountDownLatch` and sets the
  # initial value (normally equal to the number of other threads). The
  # initiating thread passes the latch to the other threads then waits for the
  # other threads by calling the `#wait` method. Each of the other threads
  # calls `#count_down` when done with its work. When the latch counter reaches
  # zero the waiting thread is unblocked and continues with its work. A
  # `CountDownLatch` can be used only once. Its value cannot be reset.
  #
  class MutexCountDownLatch

    # Create a new `CountDownLatch` with the initial `count`.
    #
    # @param [Fixnum] count
    #   The initial count
    #
    # @raise [ArgumentError]
    #   If `count` is not an integer or is less than zero.
    #
    def initialize(count = 1)
      unless count.is_a?(Fixnum) && count >= 0
        raise ArgumentError, 'count must be greater than or equal zero'
      end
      @mutex     = Mutex.new
      @condition = Condition.new
      @count     = count
    end

    # Block on the latch until the counter reaches zero or until `timeout` is
    # reached.
    #
    # @param [Fixnum] timeout
    #   The number of seconds to wait for the counter or `nil` to block
    #   indefinitely.
    # @return [Boolean]
    #   True if the count reaches zero else false on timeout.
    #
    def wait(timeout = nil)
      @mutex.synchronize do
        remaining    = Condition::Result.new(timeout)
        while @count > 0 && remaining.can_wait?
          remaining  = @condition.wait(@mutex, remaining.remaining_time)
        end
        @count == 0
      end
    end

    # Signal the latch to decrement the counter. Will signal all blocked
    # threads when the `count` reaches zero.
    #
    def count_down
      @mutex.synchronize do
        @count -= 1 if @count > 0
        @condition.broadcast if @count == 0
      end
    end

    # The current value of the counter.
    #
    # @return [Fixnum]
    #   The current value of the counter.
    #
    def count
      @mutex.synchronize { @count }
    end
  end

  class CountDownLatch < MutexCountDownLatch; end
end
