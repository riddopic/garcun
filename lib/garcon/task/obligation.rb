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
require 'timeout'
require_relative 'dereferenceable'
require_relative 'event'

module Garcon

  module Obligation
    include Dereferenceable

    # Has the obligation been fulfilled?
    #
    # @return [Boolean]
    #
    def fulfilled?
      state == :fulfilled
    end
    alias_method :realized?, :fulfilled?

    # Has the obligation been rejected?
    #
    # @return [Boolean]
    #
    def rejected?
      state == :rejected
    end

    # Is obligation completion still pending?
    #
    # @return [Boolean]
    #
    def pending?
      state == :pending
    end

    # Is the obligation still unscheduled?
    #
    # @return [Boolean]
    #
    def unscheduled?
      state == :unscheduled
    end

    # Has the obligation completed processing?
    #
    # @return [Boolean]
    #
    def complete?
      [:fulfilled, :rejected].include? state
    end

    # Is the obligation still awaiting completion of processing?
    #
    # @return [Boolean]
    #
    def incomplete?
      [:unscheduled, :pending].include? state
    end

    # The current value of the obligation. Will be `nil` while the state is
    # pending or the operation has been rejected.
    #
    # @param [Numeric]
    #   Timeout the maximum time in seconds to wait.
    #
    # @return [Object]
    #   see Dereferenceable#deref
    #
    def value(timeout = nil)
      wait timeout
      deref
    end

    # Wait until obligation is complete or the timeout has been reached.
    #
    # @param [Numeric]
    #   Timeout the maximum time in seconds to wait.
    #
    # @return [Obligation] self
    #
    def wait(timeout = nil)
      event.wait(timeout) if timeout != 0 && incomplete?
      self
    end

    # Wait until obligation is complete or the timeout is reached. Will re-raise
    # any exceptions raised during processing (but will not raise an exception
    # on timeout).
    #
    # @param [Numeric] timeout
    #   The maximum time in second to wait.
    #
    # @raise [Exception]
    #   Raises the reason when rejected`
    #
    # @return [Obligation] self
    #
    def wait!(timeout = nil)
      wait(timeout).tap { raise self if rejected? }
    end
    alias_method :no_error!, :wait!

    # The current value of the obligation. Will be `nil` while the state is
    # pending or the operation has been rejected. Will re-raise any exceptions
    # raised during processing (but will not raise an exception on timeout).
    #
    # @param [Numeric]
    #   Timeout the maximum time in seconds to wait.
    #
    # @raise [Exception]
    #   Raises the reason when rejected.
    #
    # @return [Object]
    #   see Dereferenceable#deref
    #
    def value!(timeout = nil)
      wait(timeout)
      if rejected?
        raise self
      else
        deref
      end
    end

    # The current state of the obligation.
    #
    # @return [Symbol]
    #  The current state.
    #
    def state
      mutex.lock
      @state
    ensure
      mutex.unlock
    end

    # If an exception was raised during processing this will return the
    # exception object. Will return `nil` when the state is pending or if
    # the obligation has been successfully fulfilled.
    #
    # @return [Exception]
    #   The exception raised during processing or `nil`
    #
    def reason
      mutex.lock
      @reason
    ensure
      mutex.unlock
    end

    # @example allows Obligation to be risen
    #   rejected_ivar = Ivar.new.fail
    #   raise rejected_ivar
    def exception(*args)
      raise 'obligation is not rejected' unless rejected?
      reason.exception(*args)
    end

    protected #      A T T E N Z I O N E   A R E A   P R O T E T T A

    # @!visibility private
    def get_arguments_from(opts = {})
      [*opts.fetch(:args, [])]
    end

    # @!visibility private
    def init_obligation
      init_mutex
      @event = Event.new
    end

    # @!visibility private
    def event
      @event
    end

    # @!visibility private
    def set_state(success, value, reason)
      if success
        @value  = value
        @state  = :fulfilled
      else
        @reason = reason
        @state  = :rejected
      end
    end

    # @!visibility private
    def state=(value)
      mutex.lock
      @state = value
    ensure
      mutex.unlock
    end

    # Atomic compare and set operation. State is set to `next_state` only if
    # `current state == expected_current`.
    #
    # @param [Symbol] next_state
    # @param [Symbol] expected_current
    #
    # @return [Boolean]
    #   TRrue is state is changed, false otherwise
    #
    # @!visibility private
    def compare_and_set_state(next_state, expected_current) # :nodoc:
      mutex.lock
      if @state == expected_current
        @state = next_state
        true
      else
        false
      end
    ensure
      mutex.unlock
    end

    # executes the block within mutex if current state is included in
    # expected_states
    #
    # @return block value if executed, false otherwise
    #
    # @!visibility private
    def if_state(*expected_states)
      mutex.lock
      raise ArgumentError, 'no block given' unless block_given?

      if expected_states.include? @state
        yield
      else
        false
      end
    ensure
      mutex.unlock
    end
  end
end
