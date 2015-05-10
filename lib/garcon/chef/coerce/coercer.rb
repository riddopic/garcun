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
  def self.coercer
    return @coercer if @coercer
    @coercer = Garcon::Coercer.new
    Garcon::Coercions.bind_to(@coercer)
    @coercer
  end

  def self.coercer=(coercer)
    @coercer = coercer
  end

  class Coercer
    # Coerces objects based on the definitions that are registered.
    #
    def initialize
      @coercions = Hash.new do |hash, origin|
        hash[origin] = Hash.new do |h, target|
          h[target] = Coercion.new(origin, target)
        end
      end
      @mutex = Mutex.new
    end

    # Registers a coercion with the Garcon library.
    #
    # @param [Class] origin
    #   The class to convert.
    #
    # @param [Class] target
    #   What the origin will be converted to.
    #
    def register(origin, target, &block)
      raise(ArgumentError, 'block is required') unless block_given?

      @mutex.synchronize do
        @coercions[origin][target] = Coercion.new(origin, target, &block)
      end
    end

    # Removes a coercion from the library
    #
    # @param [Class] origin
    #
    # @param [Class] target
    #
    def unregister(origin, target)
      @mutex.synchronize do
        @coercions[origin].delete(target)
      end
    end

    # @param [Object] object
    #   The object to coerce.
    #
    # @param [Class] target
    #   What you want the object to turn in to.
    #
    def coerce(object, target)
      @mutex.synchronize do
        @coercions[object.class][target].call(object)
      end
    end
  end

  # This wraps the block that is provided when you register a coercion.
  #
  class Coercion
    # Passes the object on through.
    PASS_THROUGH = ->(obj, _) { obj }

    # @param [Class] origin
    #   The class that the object is.
    #
    # @param [Class] target
    #   The class you wish to coerce to.
    #
    def initialize(origin, target, &block)
      @origin  = origin
      @target  = target
      @block   = block_given? ? block : PASS_THROUGH
    end

    # Calls the coercion.
    #
    # @return [Object]
    #
    def call(object)
      @block.call(object, @target)
    end
  end
end

require_relative 'coercions/date_definitions'
require_relative 'coercions/date_time_definitions'
require_relative 'coercions/fixnum_definitions'
require_relative 'coercions/float_definitions'
require_relative 'coercions/integer_definitions'
require_relative 'coercions/string_definitions'
require_relative 'coercions/time_definitions'
require_relative 'coercions/hash_definitions'
require_relative 'coercions/boolean_definitions'

module Garcon
  module Coercions
    def self.bind_to(coercer)
      Garcon::Coercions::DateDefinitions.bind_to(coercer)
      Garcon::Coercions::DateTimeDefinitions.bind_to(coercer)
      Garcon::Coercions::FixnumDefinitions.bind_to(coercer)
      Garcon::Coercions::FloatDefinitions.bind_to(coercer)
      Garcon::Coercions::IntegerDefinitions.bind_to(coercer)
      Garcon::Coercions::StringDefinitions.bind_to(coercer)
      Garcon::Coercions::TimeDefinitions.bind_to(coercer)
      Garcon::Coercions::HashDefinitions.bind_to(coercer)
      Garcon::Coercions::BooleanDefinitions.bind_to(coercer)
    end
  end
end
