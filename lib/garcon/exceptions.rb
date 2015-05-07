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

# Include hooks to extend Resource with class and instance methods.
#
module Garcon
  # When foo and bar collide, exceptions happen.
  #
  module Exceptions

    class UnsupportedPlatform < RuntimeError
      def initialize(platform)
        super "This functionality is not supported on platform #{platform}."
      end
    end

    class ValidationError < RuntimeError
      attr_accessor :value, :type

      def initialize(value, type = nil)
        @value, @type = value, type
        super(build_message)
        super(detail)
      end

      def build_message
        if type?
          "#{value} is not a valid #{type}"
        else
          "Failed to validate #{value.inspect}"
        end
      end

      def type?
        type.nil? ? false : true
      end

      # Pretty string output of exception/error object useful for helpful
      # debug messages.
      #
      def detail
        if backtrace
          %{#{self.class.name}: #{message}\n  #{backtrace.join("\n  ")}\n  LOGGED FROM: #{caller[0]}}
        else
          %{#{self.class.name}: #{message}\n  LOGGED FROM: #{caller[0]}}
        end
      end
    end

    # Raised when errors occur during configuration.
    ConfigurationError             = Class.new(StandardError)

    # Raised when an object's methods are called when it has not been
    # properly initialized.
    InitializationError            = Class.new(StandardError)

    # If the maximum number of ReadWriteLock readers or writers is exceeded.
    ResourceLimitError             = Class.new(StandardError)

    # Raised by an `Executor` when it is unable to process a given task,
    # possibly because of a reject policy or other internal error.
    RejectedExecutionError         = Class.new(StandardError)

    # Raised when an operation times out.
    TimeoutError                   = Class.new(StandardError)
    PollingError                   = Class.new(StandardError)

    # Raised when node[:garcon][:databag_type] is not valid.
    InvalidDataBagTypeError        = Class.new(RuntimeError)

    # Raised when cipher direction is invalid.
    InvalidCipherError             = Class.new(RuntimeError)

    # Raised when no encryption key password is specified.
    MissingEncryptionPasswordError = Class.new(RuntimeError)

    ResourceNotFoundError          = Class.new(RuntimeError)
    InvalidStateError              = Class.new(RuntimeError)
    InvalidTransitionError         = Class.new(RuntimeError)
    InvalidCallbackError           = Class.new(RuntimeError)
    TransitionFailedError          = Class.new(RuntimeError)
    TransitionConflictError        = Class.new(RuntimeError)
    GuardFailedError               = Class.new(RuntimeError)
  end
end
