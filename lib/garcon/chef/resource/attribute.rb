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

require 'chef/mash'
require 'chef/mixin/params_validate'

module Garcon
  module Resource
    class Attribute < ::Mash
      include ::Chef::Mixin::ParamsValidate

      def method_missing(method, *args, &block)
        if (match = method.to_s.match(/(.*)=$/)) && args.size == 1
          self[match[1]] = args.first
        elsif (match = method.to_s.match(/(.*)\?$/)) && args.size == 0
          key?(match[1])
        elsif key?(method)
          self[method]
        else
          super
        end
      end

      def validate(map)
        data = super(symbolize_keys, map)
        data.each { |k,v| self[k.to_sym] = v }
      end

      def self.from_hash(hash)
        mash = Attribute.new(hash)
        mash.default = hash.default
        mash
      end
    end
  end
end
