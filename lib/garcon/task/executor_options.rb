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

require_relative 'immediate_executor'

module Garcon
  module ExecutorOptions

    # Get the requested `Executor` based on the values set in the options hash.
    #
    # @param [Hash] opts
    #   The options defining the requested executor.
    #
    # @option opts [Executor] :executor
    #   When set use the given `Executor` instance. Three special values are
    #   also supported: `:fast` returns the global fast executor, `:io` returns
    #   the global io executor, and `:immediate` returns a new
    #   `ImmediateExecutor` object.
    #
    # @return [Executor, nil]
    #   The requested thread pool, or nil when no option specified.
    #
    # @!visibility private
    def get_executor_from(opts = {})
      if (executor = opts[:executor]).is_a? Symbol
        case opts[:executor]
        when :fast
          Garcon.global_fast_executor
        when :io
          Garcon.global_io_executor
        when :immediate
          Garcon::ImmediateExecutor.new
        else
          raise ArgumentError, "executor '#{executor}' not recognized"
        end
      elsif opts[:executor]
        opts[:executor]
      else
        nil
      end
    end
  end
end
