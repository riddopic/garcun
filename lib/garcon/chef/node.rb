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

# To get to node we have to go through Chef, happy Rubocop?
#
class Chef
  # Slap some dandy handy methods to stick on a node.
  #
  class Node
    # Boolean to check if a recipe is loaded in the run list.
    #
    # @param [String] recipe
    #   the command to find
    #
    # @return [TrueClass, FalseClass]
    #   true if the command is found in the path, false otherwise
    #
    # @api public
    def has_recipe?(recipe)
      loaded_recipes.include?(with_default(recipe))
    end
    alias_method :include_recipe?,  :has_recipe?
    alias_method :includes_recipe?, :has_recipe?

    # Determine if the current node is in the given Chef environment
    # (or matches the given regular expression).
    #
    # @param [String, Regex] environment
    #
    # @return [Boolean]
    #
    # @api public
    def in?(environment)
      environment === chef_environment
    end

    # Recursively searchs a nested datastructure for a key and returns the
    # value. If a block is provided its value will be returned if the key does
    # not exist, otherwise UndefinedAttributeError is raised.
    #
    # @param [Array<String, Symbol>] keys
    #   The list of keys to kdeep fetch
    #
    # @yield optional block to execute if no value is found
    #
    # @raise UndefinedAttributeError
    #
    # @return [Object]
    #
    # @api public
    def get(*keys, &block)
      keys.reduce(self) do |obj, key|
        begin
          key = Integer(key) if obj.is_a? Array
          obj.fetch(key)
        rescue ArgumentError, IndexError, NoMethodError
          break block.call(key) if block
          raise UndefinedAttributeError
        end
      end
    end
    alias_method :deep_fetch, :get

    private #        P R O P R I E T À   P R I V A T A   Vietato L'accesso

    # Automatically appends "::default" to recipes that need them.
    #
    # @param [String] recipe
    #
    # @return [String]
    #
    # @api private
    def with_default(recipe)
      name.include?('::') ? name : "#{recipe}::default"
    end

    # The list of loaded recipes on the Chef run (normalized)
    #
    # @return [Array<String>]
    #
    # @api private
    def loaded_recipes
      node.run_context.loaded_recipes.map { |name| with_default(name) }
    end
  end
end
