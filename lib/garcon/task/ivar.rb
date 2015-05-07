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

require_relative '../exceptions'
require_relative 'obligation'
require_relative 'observable'

module Garcon

  # An `IVar` is like a future that you can assign. As a future is a value that
  # is being computed that you can wait on, an `IVar` is a value that is waiting
  # to be assigned, that you can wait on. `IVars` are single assignment and
  # deterministic.
  #
  # Then, express futures as an asynchronous computation that assigns an `IVar`.
  # The `IVar` becomes the primitive on which [futures](Future) and
  # [dataflow](Dataflow) are built.
  #
  # An `IVar` is a single-element container that is normally created empty, and
  # can only be set once. The I in `IVar` stands for immutable. Reading an
  # `IVar` normally blocks until it is set. It is safe to set and read an `IVar`
  # from different threads.
  #
  # If you want to have some parallel task set the value in an `IVar`, you want
  # a `Future`. If you want to create a graph of parallel tasks all executed
  # when the values they depend on are ready you want `dataflow`. `IVar` is
  # generally a low-level primitive.
  #
  # @example Create, set and get an `IVar`
  #   ivar = Garcon::IVar.new
  #   ivar.set 14
  #   ivar.get #=> 14
  #   ivar.set 2 # would now be an error
  #
  class IVar
    include Obligation
    include Observable

    # @!visibility private
    NO_VALUE = Object.new

    # Create a new `IVar` in the `:pending` state with the (optional) initial
    # value.
    #
    # @param [Object] value
    #   The initial value.
    #
    # @param [Hash] opts the options to create a message with.
    #
    # @option opts [String] :dup_on_deref (false)
    #   Call `#dup` before returning the data.
    #
    # @option opts [String] :freeze_on_deref (false)
    #   Call `#freeze` before returning the data.
    #
    # @option opts [String] :copy_on_deref (nil)
    #   Cll the given `Proc` passing the internal value and returning the value
    #   returned from the proc.
    #
    def initialize(value = NO_VALUE, opts = {})
      init_obligation
      self.observers = CopyOnWriteObserverSet.new
      set_deref_options(opts)

      if value == NO_VALUE
        @state = :pending
      else
        set(value)
      end
    end

    # Add an observer on this object that will receive notification on update.
    #
    # Upon completion the `IVar` will notify all observers in a thread-safe way.
    # The `func` method of the observer will be called with three arguments: the
    # `Time` at which the `Future` completed the asynchronous operation, the
    # final `value` (or `nil` on rejection), and the final `reason` (or `nil` on
    # fulfillment).
    #
    # @param [Object] observer
    #   The object that will be notified of changes.
    #
    # @param [Symbol] func
    #   Symbol naming the method to call when the `Observable` has changes`
    #
    def add_observer(bsrver = nil, func = :update, &block)
      if observer && block
        raise ArgumentError, 'cannot provide both an observer and a block'
      end
      direct_notification = false

      if block
        observer = block
        func     = :call
      end

      mutex.synchronize do
        if event.set?
          direct_notification = true
        else
          observers.add_observer(observer, func)
        end
      end

      observer.send(func, Time.now, self.value, reason) if direct_notification
      observer
    end

    # Set the `IVar` to a value and wake or notify all threads waiting on it.
    #
    # @param [Object] value
    #   The value to store in the `IVar`.
    #
    # @raise [Garcon::MultipleAssignmentError]
    #   If the `IVar` has already been set or otherwise completed.
    #
    # @return [IVar] self
    #
    def set(value)
      complete(true, value, nil)
    end

    # Set the `IVar` to failed due to some error and wake or notify all threads
    # waiting on it.
    #
    # @param [Object] reason
    #   For the failure.
    #
    # @raise [Garcon::MultipleAssignmentError]
    #   If the `IVar` has already been set or otherwise completed.
    #
    # @return [IVar] self
    #
    def fail(reason = StandardError.new)
      complete(false, nil, reason)
    end

    # @!visibility private
    def complete(success, value, reason)
      mutex.synchronize do
        if [:fulfilled, :rejected].include? @state
          raise MultipleAssignmentError, 'multiple assignment'
        end
        set_state(success, value, reason)
        event.set
      end

      time = Time.now
      observers.notify_and_delete_observers{ [time, self.value, reason] }
      self
    end
  end
end
