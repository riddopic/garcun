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

  # Lazy evaluation of a block yielding an immutable result. Useful for
  # expensive operations that may never be needed. `LazyReference` is a simpler,
  # blocking version of `Delay` and has an API similar to `AtomicReference`.
  # The first time `#value` is called the caller will block until the
  # block given at construction is executed. Once the result has been
  # computed the value will be immutably set. Any exceptions thrown during
  # computation will be suppressed.
  #
  class LazyReference

    # Creates a new unfulfilled object.
    #
    # @yield the delayed operation to perform
    #
    # @param [Object] default
    #   The default value for the object when the block raises an exception.
    #
    # @raise [ArgumentError] if no block is given
    #
    def initialize(default = nil, &block)
      raise ArgumentError, 'no block given' unless block_given?
      @default   = default
      @task      = block
      @mutex     = Mutex.new
      @value     = nil
      @fulfilled = false
    end

    # The calculated value of the object or the default value if one was given
    # at construction. This first time this method is called it will block
    # indefinitely while the block is processed. Subsequent calls will not
    # block.
    #
    # @return [Object] the calculated value
    #
    def value
      return @value if @fulfilled

      @mutex.synchronize do
        unless @fulfilled
          begin
            @value = @task.call
          rescue
            @value = @default
          ensure
            @fulfilled = true
          end
        end
        return @value
      end
    end
  end
end
