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
  # Define update methods that use direct paths
  module AtomicDirectUpdate

    # Pass the current value to the given block, replacing it with the block's
    # result. May retry if the value changes during the block's execution.
    #
    # @yield [Object]
    #   Calculate a new value for the atomic reference using given (old) value.
    # @yieldparam [Object] old_value
    #   The starting value of the atomic reference
    #
    # @return [Object]
    #   The new value
    def update
      true until compare_and_set(old_value = get, new_value = yield(old_value))
      new_value
    end

    # Pass the current value to the given block, replacing it with the block's
    # result. Raise an exception if the update fails.
    #
    # @yield [Object]
    #   Calculate a new value for the atomic reference using given (old) value.
    # @yieldparam [Object] old_value
    #   The starting value of the atomic reference.
    #
    # @raise [Garcon::ConcurrentUpdateError]
    #   If the update fails
    #
    # @return [Object] the new value
    def try_update
      old_value = get
      new_value = yield old_value
      unless compare_and_set(old_value, new_value)
        raise ConcurrentUpdateError, "Update failed"
      end
      new_value
    end
  end

  # Special "compare and set" handling of numeric values.
  module AtomicNumericCompareAndSetWrapper

    def compare_and_set(old_value, new_value)
      if old_value.kind_of? Numeric
        while true
          old = get

          return false unless old.kind_of? Numeric

          return false unless old == old_value

          result = _compare_and_set(old, new_value)
          return result if result
        end
      else
        _compare_and_set(old_value, new_value)
      end
    end
    alias_method :compare_and_swap, :compare_and_set
  end

  class AtomicMutex
    include Garcon::AtomicDirectUpdate
    include Garcon::AtomicNumericCompareAndSetWrapper

    def initialize(value = nil)
      @mutex = Mutex.new
      @value = value
    end

    # Gets the current value.
    #
    # @return [Object]
    #   The current value.
    def get
      @mutex.synchronize { @value }
    end
    alias_method :value, :get

    # Sets to the given value.
    #
    # @param [Object] value
    #   The new value to set.
    #
    # @return [Object]
    #   The new value.
    def set(value)
      @mutex.synchronize { @value = value }
    end
    alias_method :value=, :set

    # Atomically sets to the given value and returns the old value.
    #
    # @param [Object] value
    #   The new value to set.
    #
    # @return [Object]
    #   The old value.
    def get_and_set(new_value)
      @mutex.synchronize do
        old_value = @value
        @value = new_value
        old_value
      end
    end
    alias_method :swap, :get_and_set

    # Atomically sets the value to the given updated value if the current value
    # is equal the expected value.
    #
    # @param [Object] old_value
    #   The expected value.
    # @param [Object] new_value
    #   The new value.
    #
    # @return [Boolean]
    #   `true` if successful, `false` indicates that the actual value was not
    #   equal to the expected value.
    def _compare_and_set(old_value, new_value)
      return false unless @mutex.try_lock
      begin
        return false unless @value.equal? old_value
        @value = new_value
      ensure
        @mutex.unlock
      end
      true
    end
  end
end
