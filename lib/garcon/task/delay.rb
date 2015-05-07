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
require_relative 'obligation'
require_relative 'executor_options'
require_relative 'immediate_executor'

module Garcon

  # Lazy evaluation of a block yielding an immutable result. Useful for
  # expensive operations that may never be needed. It may be non-blocking,
  # supports the `Obligation` interface, and accepts the injection of custom
  # executor upon which to execute the block. Processing of block will be
  # deferred until the first time `#value` is called. At that time the caller
  # can choose to return immediately and let the block execute asynchronously,
  # block indefinitely, or block with a timeout.
  #
  # When a `Delay` is created its state is set to `pending`. The value and
  # reason are both `nil`. The first time the `#value` method is called the
  # enclosed opration will be run and the calling thread will block. Other
  # threads attempting to call `#value` will block as well. Once the operation
  # is complete the *value* will be set to the result of the operation or the
  # *reason* will be set to the raised exception, as appropriate. All threads
  # blocked on `#value` will return. Subsequent calls to `#value` will
  # immediately return the cached value. The operation will only be run once.
  # This means that any side effects created by the operation will only happen
  # once as well.
  #
  # `Delay` includes the `Garcon::Dereferenceable` mixin to support thread
  # safety of the reference returned by `#value`.
  #
  # @!macro [attach] delay_note_regarding_blocking
  #   @note The default behavior of `Delay` is to block indefinitely when
  #     calling either `value` or `wait`, executing the delayed operation on
  #     the current thread. This makes the `timeout` value completely
  #     irrelevant. To enable non-blocking behavior, use the `executor`
  #     constructor option. This will cause the delayed operation to be
  #     execute on the given executor, allowing the call to timeout.
  #
  # @see Garcon::Dereferenceable
  class Delay
    include Obligation
    include ExecutorOptions

    # Create a new `Delay` in the `:pending` state.
    #
    # @yield the delayed operation to perform
    #
    # @raise [ArgumentError] if no block is given
    #
    def initialize(opts = {}, &block)
      raise ArgumentError, 'no block given' unless block_given?
      init_obligation
      set_deref_options(opts)
      @task_executor = get_executor_from(opts)
      @task          = block
      @state         = :pending
      @computing     = false
    end

    # Return the value this object represents after applying the options
    # specified by the `#set_deref_options` method. If the delayed operation
    # raised an exception this method will return nil. The execption object
    # can be accessed via the `#reason` method.
    #
    # @param [Numeric]
    #   Timeout the maximum number of seconds to wait.
    #
    # @return [Object] the current value of the object.
    #
    def value(timeout = nil)
      if @task_executor
        super
      else
        mutex.synchronize do
          execute = @computing = true unless @computing
          if execute
            begin
              set_state(true, @task.call, nil)
            rescue => e
              set_state(false, nil, e)
            end
          end
        end
        if @do_nothing_on_deref
          @value
        else
          apply_deref_options(@value)
        end
      end
    end

    # Return the value this object represents after applying the options
    # specified by the `#set_deref_options` method. If the delayed operation
    # raised an exception, this method will raise that exception (even when)
    # the operation has already been executed).
    #
    # @param [Numeric]
    #   Timeout the maximum number of seconds to wait.
    #
    # @raise [Exception] when `#rejected?` raises `#reason`.
    #
    # @return [Object]
    #   The current value of the object.
    #
    def value!(timeout = nil)
      if @task_executor
        super
      else
        result = value
        raise @reason if @reason
        result
      end
    end

    # Return the value this object represents after applying the options
    # specified by the `#set_deref_options` method.
    #
    # @param [Integer]
    #   Timeout (nil) the maximum number of seconds to wait for the value to be
    #   computed. When `nil` the caller will block indefinitely.
    #
    # @return [Object] self
    #
    def wait(timeout = nil)
      if @task_executor
        execute_task_once
        super(timeout)
      else
        value
      end
      self
    end

    # Reconfigures the block returning the value if still `#incomplete?`
    #
    # @yield the delayed operation to perform
    #
    # @return [true, false] if success
    #
    def reconfigure(&block)
      mutex.lock
      raise ArgumentError.new('no block given') unless block_given?
      unless @computing
        @task = block
        true
      else
        false
      end
    ensure
      mutex.unlock
    end

    private

    # @!visibility private
    def execute_task_once
      mutex.lock
      execute = @computing = true unless @computing
      task    = @task
      mutex.unlock

      if execute
        @task_executor.post do
          begin
            result  = task.call
            success = true
          rescue => e
            reason = e
          end
          mutex.lock
          set_state(success, result, reason)
          event.set
          mutex.unlock
        end
      end
    end
  end
end
