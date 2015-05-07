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

# Lazy ass Ruby.
#
module Lazy
  # Raised when a demanded computation diverges (e.g. if it tries to directly
  # use its own result)
  #
  class DivergenceError < Exception
    def initialize(message = 'Computation diverges')
      super(message)
    end
  end

  # Wraps an exception raised by a lazy computation.
  #
  # The reason we wrap such exceptions in LazyException is that they need to
  # be distinguishable from similar exceptions which might normally be raised
  # by whatever strict code we happen to be in at the time.
  #
  class LazyException < DivergenceError
    attr_reader :reason

    def initialize(reason)
      @reason = reason
      super "Exception in lazy computation: #{reason} (#{reason.class})"
      set_backtrace(reason.backtrace.dup) if reason
    end
  end

  # A handle for a promised computation.  They are transparent, so that in
  # most cases, a promise can be used as a proxy for the computation's result
  # object.  The one exception is truth testing -- a promise will always look
  # true to Ruby, even if the actual result object is nil or false.
  #
  # If you want to test the result for truth, get the unwrapped result object
  # via Kernel.demand.
  #
  class Promise
    alias __class__ class
    instance_methods.each do |method|
      undef_method method unless method =~ /^(__|object_|instance_)/
    end

    def initialize(&computation)
      @computation = computation
    end

    def __synchronize__
      yield
    end

    # Create this once here, rather than creating a proc object for every
    # evaluation.
    DIVERGES = lambda { raise DivergenceError.new }

    # Differentiate inspection of DIVERGES lambda.
    def DIVERGES.inspect
      'DIVERGES'
    end

    def __result__
      __synchronize__ do
        if @computation
          raise LazyException.new(@exception) if @exception

          computation  = @computation
          @computation = DIVERGES

          begin
            @result = demand(computation.call(self))
            @computation = nil
          rescue DivergenceError
            raise
          rescue Exception => e
            @exception = e
            raise LazyException.new(@exception)
          end
        end

        @result
      end
    end

    def inspect
      __synchronize__ do
        if @computation
          "#<#{__class__} computation=#{@computation.inspect}>"
        else
          @result.inspect
        end
      end
    end

    def respond_to?(message)
      message  = message.to_sym
      message == :__result__ or
      message == :inspect    or
      __result__.respond_to? message
    end

    def method_missing(*args, &block)
      __result__.__send__(*args, &block)
    end
  end

  # Thread safe version of Promise class.
  #
  class PromiseSafe < Promise
    def __synchronize__
      current = Thread.current

      Thread.critical = true
      unless @computation
        Thread.critical = false
        yield
      else
        if @owner == current
          Thread.critical = false
          raise DivergenceError.new
        end
        while @owner
          Thread.critical = false
          Thread.pass
          Thread.critical = true
        end
        @owner = current
        Thread.critical = false

        begin
          yield
        ensure
          @owner = nil
        end
      end
    end
  end

  # Future class subclasses PromiseSafe.
  #
  class Future < PromiseSafe
    def initialize(&computation)
      result    = nil
      exception = nil
      thread    = Thread.new do
        begin
          result = computation.call(self)
        rescue Exception => exception
        end
      end

      super do
        raise DivergenceError.new if Thread.current == thread
        thread.join
        raise exception if exception
        result
      end
    end
  end
end

module Kernel
  # The promise() function is used together with demand() to implement
  # lazy evaluation.  It returns a promise to evaluate the provided
  # block at a future time.  Evaluation can be demanded and the block's
  # result obtained via the demand() function.
  #
  # Implicit evaluation is also supported: the first message sent to it will
  # demand evaluation, after which that message and any subsequent messages
  # will be forwarded to the result object.
  #
  # As an aid to circular programming, the block will be passed a promise
  # for its own result when it is evaluated.  Be careful not to force
  # that promise during the computation, lest the computation diverge.
  #
  def promise(&computation)
    Lazy::Promise.new(&computation)
  end

  # Forces the result of a promise to be computed (if necessary) and returns
  # the bare result object.  Once evaluated, the result of the promise will
  # be cached.  Nested promises will be evaluated together, until the first
  # non-promise result.
  #
  # If called on a value that is not a promise, it will simply return it.
  #
  def demand(promise)
    if promise.respond_to? :__result__
      promise.__result__
    else
      promise
    end
  end

  # Schedules a computation to be run asynchronously in a background thread
  # and returns a promise for its result.  An attempt to demand the result of
  # the promise will block until the computation finishes.
  #
  # As with Kernel.promise, this passes the block a promise for its own result.
  # Use wisely.
  #
  def future(&computation)
    Lazy::Future.new(&computation)
  end
end
