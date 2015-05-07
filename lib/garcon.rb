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

#                   ____   ____  ____      __   ___   ____
#                  /    T /    T|    \    /  ] /   \ |    \
#                 Y   __jY  o  ||  D  )  /  / Y     Y|  _  Y
#                 |  T  ||     ||    /  /  /  |  O  ||  |  |
#                 |  l_ ||  _  ||    \ /   \_ |     ||  |  |
#                 |     ||  |  ||  .  Y\     |l     !|  |  |
#                 l___,_jl__j__jl__j\_j \____j \___/ l__j__j

require 'chef/recipe'
require 'chef/resource'
require 'chef/provider'

require_relative 'garcon/version'
require_relative 'garcon/configuration'
require_relative 'garcon/exceptions'
require_relative 'garcon/inflections'
require_relative 'garcon/secret'
require_relative 'garcon/stash/store'
require_relative 'garcon/core_ext'
require_relative 'garcon/task'
require_relative 'garcon/utils'

# Pirla o Sfigato Magnà  Capo  Fregna

module Garcon
  # Extends base class or a module with garcon methods, called when module is
  # included, extends the object with class and instance methods.
  #
  # @param [Object] object
  #   The object including Garcon
  #
  # @return [self]
  #
  # @api private
  def self.included(object)
    super
    if Class === object
      object.send(:include, ClassInclusions) # TODO fix this...
    else
      object.extend(ModuleExtensions)
    end
  end
  private_class_method :included

  # Extends an object with garcon extensions, called when module is extended,
  # extends the object with class and instance methods.
  #
  # @param [Object] object
  #   The object including Garcon.
  #
  # @return [self]
  #
  # @api private
  def self.extended(object)
    object.extend(Extensions)
  end
  private_class_method :extended

  # Sets the global Crypto configuration.
  #
  # @example
  #   Garcon.config do |c|
  #     c.crypto.password = "!mWh0!s@y!m"
  #     c.crypto.salt     = "9e5f851900cad8892ac8b737b7370cbe"
  #   end
  #
  # @return [Garcon::Crypto]
  #
  # @api public
  def self.crypto(&block)
    configuration.crypto(&block)
  end

  # Sets the global Crypto configuration value.
  #
  # @param [Boolean] value
  #
  # @return [Garcon::Crypto]
  #
  # @api public
  def self.crypto=(value)
    configuration.crypto = value
    self
  end

  # Returns the global Crypto setting.
  #
  # @return [Boolean]
  #
  # @api public
  def self.crypto
    configuration.crypto
  end

  # Sets the global Secret configuration.
  #
  # @return [Garcon::Secret]
  #
  # @api public
  def self.secret(&block)
    configuration.secret(&block)
  end

  # Sets the global Secret configuration value.
  #
  # @param [Boolean] value
  #
  # @return [Garcon::Secret]
  #
  # @api public
  def self.secret=(value)
    configuration.secret = value
    self
  end

  # Returns the global Secret setting.
  #
  # @return [Boolean]
  #
  # @api public
  def self.secret
    configuration.secret
  end

  # Provides access to the global Garcon configuration
  #
  # @example
  #   Garcon.config do |config|
  #     config.blender = true
  #   end
  #
  # @return [Configuration]
  #
  # @api public
  def self.config(&block)
    yield configuration if block_given?
    configuration
  end

  # Global configuration instance.
  #
  # @return [Configuration]
  #
  # @api private
  def self.configuration
    @configuration ||= Configuration.new
  end

  # Defines if global executors should be auto-terminated with an `at_exit`
  # callback. When set to `false` it will be the application programmer's
  # responsibility to ensure that the global thread pools are shutdown properly
  # prior to application exit.
  #
  def self.disable_auto_termination_of_global_executors!
    Garcon.config.auto_terminate_global_executors.make_false
  end
  #
  # @return [Boolean]
  #   true when global thread pools will auto-terminate on application exit
  #   using an `at_exit` handler; false when no auto-termination will occur.
  #
  def self.auto_terminate_global_executors?
    Garcon.config.auto_terminate_global_executors.value
  end

  # Defines if *ALL* executors should be auto-terminated with an `at_exit`
  # callback. When set to `false` it will be the application programmer's
  # responsibility to ensure that *all* thread pools, including the global
  # thread pools, are shutdown properly prior to application exit.
  #
  def self.disable_auto_termination_of_all_executors!
    Garcon.config.auto_terminate_all_executors.make_false
  end

  # @return [Boolean]
  #   true when *all* thread pools will auto-terminate on application exit
  #   using an `at_exit` handler; false when no auto-termination will occur.
  #
  def self.auto_terminate_all_executors?
    Garcon.config.auto_terminate_all_executors.value
  end

  # Global thread pool optimized for short, fast *operations*.
  #
  # @return [ThreadPoolExecutor] the thread pool
  def self.global_fast_executor
    Garcon.config.global_fast_executor.value
  end

  # Global thread pool optimized for long, blocking (IO) *tasks*.
  #
  # @return [ThreadPoolExecutor] the thread pool
  def self.global_io_executor
    Garcon.config.global_io_executor.value
  end

  # Global thread pool user for global *timers*.
  #
  # @return [Garcon::TimerSet] the thread pool
  #
  # @see Garcon::timer
  def self.global_timer_set
    Garcon.config.global_timer_set.value
  end

  def self.shutdown_global_executors
    global_fast_executor.shutdown
    global_io_executor.shutdown
    global_timer_set.shutdown
  end

  def self.kill_global_executors
    global_fast_executor.kill
    global_io_executor.kill
    global_timer_set.kill
  end

  def self.wait_for_global_executors_termination(timeout = nil)
    latch = CountDownLatch.new(3)
    [ global_fast_executor, global_io_executor, global_timer_set ].each do |ex|
      Thread.new { ex.wait_for_termination(timeout); latch.count_down }
    end
    latch.wait(timeout)
  end

  def self.new_fast_executor(opts = {})
    FixedThreadPool.new(
      [2, Garcon.processor_count].max,
      stop_on_exit:     opts.fetch(:stop_on_exit, true),
      idletime:         60,         # 1 minute
      max_queue:        0,          # unlimited
      fallback_policy: :caller_runs # shouldn't matter -- 0 max queue
    )
  end

  def self.new_io_executor(opts = {})
    ThreadPoolExecutor.new(
      min_threads:      [2, Garcon.processor_count].max,
      max_threads:      ThreadPoolExecutor::DEFAULT_MAX_POOL_SIZE,
      stop_on_exit:     opts.fetch(:stop_on_exit, true),
      idletime:         60,         # 1 minute
      max_queue:        0,          # unlimited
      fallback_policy: :caller_runs # shouldn't matter -- 0 max queue
    )
  end

  # @return [String] object inspection
  # @api public
  def inspect
    instance_variables.inject([
      "\n#<#{self.class}:0x#{object_id.to_s(16)}>",
      "\tInstance variables:"
    ]) do |result, item|
      result << "\t\t#{item} = #{instance_variable_get(item)}"
      result
    end.join("\n")
  end

  # @return [String] string of instance
  # @api public
  def to_s
    "<#{self.class}:0x#{object_id.to_s(16)}>"
  end

  # @api private
  def self.warn(msg)
    Kernel.warn(msg)
  end
end

require_relative 'garcon/chef_inclusions'
