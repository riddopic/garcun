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
  module Interpolation
    # Methods are also available as module-level methods as well as a mixin.
    extend self

    # Interpolate provides a means of externally using Ruby string
    # interpolation mechinism.
    #
    # @example
    #   node[:ldap][:basedir] = '/opt'
    #   node[:ldap][:homedir] = '%{basedir}/openldap/slap/happy'
    #
    #   interpolate(node[:ldap])[:homedir]  # => "/opt/openldap/slap/happy"
    #
    # @param [String] item
    #   The string to interpolate.
    #
    # @param [String, Hash] parent
    #   The string used for substitution.
    #
    # @return [String]
    #   The interpolated string.
    #
    # @api public
    def interpolate(item = self, parent = nil)
      item = render item, parent
      item.is_a?(Hash) ? ::Mash.new(item) : item
    end

    private #        P R O P R I E T À   P R I V A T A   Vietato L'accesso

    # Return a symbol if key is a symbol using duck quacking.
    #
    # @param [Object] key
    #   The object to duck quack for a :to_sym method.
    #
    # @return [Boolean]
    #    True if object reponds to :to_sym quack duck, else false.
    #
    # @api private
    def sym(key)
      key.respond_to?(:to_sym) ? key.to_sym : key
    end

    # Provides recursive interpolation of node objects, using standard
    # string interpolation methods.
    #
    # @param [String] item
    #   The string to interpolate.
    #
    # @param [String, Hash] parent
    #   The string used for substitution.
    #
    # @return [String]
    #
    # @api private
    def render(item, parent = nil)
      item = item.to_hash if item.respond_to?(:to_hash)
      if item.is_a?(Hash)
        item = item.inject({}) { |memo, (k,v)| memo[sym(k)] = v; memo }
        item.inject({}) {|memo, (k,v)| memo[sym(k)] = render(v, item); memo}
      elsif item.is_a?(Array)
        item.map { |i| render(i, parent) }
      elsif item.is_a?(String)
        item % parent rescue item
      else
        item
      end
    end
  end
end
