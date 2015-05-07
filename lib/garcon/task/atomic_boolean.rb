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

  # A boolean value that can be updated atomically. Reads and writes to an
  # atomic boolean and thread-safe and guaranteed to succeed. Reads and writes
  # may block briefly but no explicit locking is required.
  #
  class MutexAtomicBoolean

    # Creates a new `AtomicBoolean` with the given initial value.
    #
    # @param [Boolean] initial
    #   the initial value
    #
    # @api public
    def initialize(initial = false)
      @value = !!initial
      @mutex = Mutex.new
    end

    # Retrieves the current `Boolean` value.
    #
    # @return [Boolean]
    #   the current value
    #
    # @api public
    def value
      @mutex.lock
      @value
    ensure
      @mutex.unlock
    end

    # Explicitly sets the value.
    #
    # @param [Boolean] value
    #   the new value to be set
    #
    # @return [Boolean]
    #   the current value
    #
    # @api public
    def value=(value)
      @mutex.lock
      @value = !!value
      @value
    ensure
      @mutex.unlock
    end

    # Is the current value `true`
    #
    # @return [Boolean]
    #   True if the current value is `true`, else false
    #
    # @api public
    def true?
      @mutex.lock
      @value
    ensure
      @mutex.unlock
    end

    # Is the current value `false`
    #
    # @return [Boolean]
    #   True if the current value is `false`, else false
    #
    # @api public
    def false?
      @mutex.lock
      !@value
    ensure
      @mutex.unlock
    end

    # Explicitly sets the value to true.
    #
    # @return [Boolean]
    #   True is value has changed, otherwise false
    #
    # @api public
    def make_true
      @mutex.lock
      old = @value
      @value = true
      !old
    ensure
      @mutex.unlock
    end

    # Explicitly sets the value to false.
    #
    # @return [Boolean]
    #   True is value has changed, otherwise false
    #
    # @api public
    def make_false
      @mutex.lock
      old = @value
      @value = false
      old
    ensure
      @mutex.unlock
    end
  end

  class AtomicBoolean < MutexAtomicBoolean; end
end
