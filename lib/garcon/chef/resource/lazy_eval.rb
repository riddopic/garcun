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
  module Resource
    # Resource mixin to allow lazyily-evaluated defaults in resource attributes.
    #
    module LazyEval
      module ClassMethods
        # Create a lazyily-evaluated block.
        #
        # @param [Proc] block
        #   Callable to return the default value.
        #
        # @return [Chef::DelayedEvaluator]
        #
        def lazy(&block)
          Chef::DelayedEvaluator.new(&block)
        end

        # Hook called when module is included, extends a descendant with class
        # and instance methods.
        #
        # @param [Module] descendant
        #   the module or class including Garcon::Resource::LazyEval
        #
        # @return [self]
        #
        def included(descendant)
          super
          descendant.extend ClassMethods
        end
      end

      extend ClassMethods

      # Override the default set_or_return to support lazy evaluation of the
      # default value. This only actually matters when it is called from a class
      # level context via #attributes.
      #
      def set_or_return(symbol, arg, validation)
        if validation && validation[:default].is_a?(Chef::DelayedEvaluator)
          validation = validation.dup
          validation[:default] = instance_eval(&validation[:default])
        end
        super(symbol, arg, validation)
      end
    end
  end
end
