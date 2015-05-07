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
  # Configuration instance
  #
  class Configuration

    # Access the minimum number of threads setting for this instance.
    attr_accessor :min_threads

    # Access the maximum number of threads setting for this instance.
    attr_accessor :max_threads

    # @!attribute [rw] auto_terminate_global_executors
    #   @return [Boolean] Defines if global executors should be auto-terminated
    #     with an `at_exit` callback. When set to `false` it will be the
    #     application programmer's responsibility to ensure that the global
    #     thread pools are shutdown properly prior to application exit.
    attr_accessor :auto_terminate_global_executors

    # @!attribute [rw] auto_terminate_all_executors
    #   @return [Boolean] Defines if global executors should be auto-terminated
    #     with an `at_exit` callback. When set to `false` it will be the
    #     application programmer's responsibility to ensure that the global
    #     thread pools are shutdown properly prior to application exit.
    attr_accessor :auto_terminate_all_executors

    # Global thread pool optimized for short, fast *operations*.
    #
    # @!attribute [ro] global_fast_executor
    #   @return [ThreadPoolExecutor] the thread pool
    attr_reader :global_fast_executor

    # Global thread pool optimized for long, blocking (IO) *tasks*.
    #
    # @!attribute [ro] global_io_executor
    #   @return [ThreadPoolExecutor] the thread pool
    attr_reader :global_io_executor

    # Global thread pool user for global *timers*.
    #
    # @!attribute [ro] global_timer_set
    #   @return [Garcon::TimerSet] the thread pool
    attr_reader :global_timer_set

    # Initialized a configuration instance.
    #
    # @return [undefined]
    #
    # @api private
    def initialize(opts = {})
      @min_threads = opts.fetch(:min_threads, [2, Garcon.processor_count].max)
      @max_threads = opts.fetch(:max_threads,     Garcon.processor_count * 100)

      @crypto = Crypto::Configuration.new
      @secret = Secret::Configuration.new

      @auto_terminate_global_executors = AtomicBoolean.new(true)
      @auto_terminate_all_executors    = AtomicBoolean.new(true)

      @global_fast_executor = Delay.new do
        Garcon.new_fast_executor(
          stop_on_exit: @auto_terminate_global_executors.value)
      end

      @global_io_executor = Delay.new do
        Garcon.new_io_executor(
          stop_on_exit: @auto_terminate_global_executors.value)
      end

      @global_timer_set = Delay.new do
        TimerSet.new(stop_on_exit: @auto_terminate_global_executors.value)
      end

      yield self if block_given?
    end

    # Access the crypto for this instance and optional configure a
    # new crypto with the passed block.
    #
    # @example
    #   Garcon.config do |c|
    #     c.crypto.password = "!mWh0!s@y!m"
    #     c.crypto.salt     = "9e5f851900cad8892ac8b737b7370cbe"
    #   end
    #
    # @return [Crypto]
    #
    # @api private
    def crypto(&block)
      @crypto = Crypto::Configuration.new(&block) if block_given?
      @crypto
    end

    # Access the secret stash hash cash store for this instance and optional
    # configure a new secret with the passed block.
    #
    # @return [Secret]
    #
    # @api private
    def secret(&block)
      @secret = Secret::Configuration.new(&block) if block_given?
      @secret
    end

    # @api private
    def to_h
      { crypto:                          crypto,
        secret:                          secret,
        blender:                         blender,
        min_threads:                     min_threads,
        max_threads:                     max_threads,
        global_timer_set:                global_timer_set,
        global_io_executor:              global_io_executor,
        global_fast_executor:            global_fast_executor,
        auto_terminate_all_executors:    auto_terminate_all_executors,
        auto_terminate_global_executors: auto_terminate_global_executors
      }.freeze
    end
  end
end
