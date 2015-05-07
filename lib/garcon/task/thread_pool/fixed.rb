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

require_relative 'executor'

module Garcon

  class FixedThreadPool < ThreadPoolExecutor

    # Create a new thread pool.
    #
    # @param [Integer] num_threads
    #   The number of threads to allocate.
    #
    # @param [Hash] opts
    #   The options defining pool behavior.
    #
    # @option opts [Symbol] :fallback (`:abort`)
    #   The fallback policy
    #
    # @raise [ArgumentError] if `num_threads` is less than or equal to zero
    #
    # @raise [ArgumentError] if `fallback` is not a known policy
    #
    # @api public
    def initialize(num_threads, opts = {})
      fallback = opts.fetch(:fallback, :abort)

      if num_threads < 1
        raise ArgumentError, 'number of threads must be greater than zero'
      elsif !FALLBACK_POLICY.include?(fallback)
        raise ArgumentError, "#{fallback} is not a valid fallback policy"
      end

      opts = opts.merge(
        min_threads: num_threads,
        max_threads: num_threads,
        fallback:    fallback,
        max_queue:   DEFAULT_MAX_QUEUE_SIZE,
        idletime:    DEFAULT_THREAD_IDLETIMEOUT)

      super(opts)
    end
  end
end
