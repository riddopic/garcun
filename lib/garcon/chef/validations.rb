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

require 'uri'

# Resource validations.
#
module Garcon
  module Resource
    module Validations
      module ClassMethods
        # Callback for source URL validation.
        #
        # @return [Proc]
        #
        def source_callbacks
          { 'Source must be an absolute URI' => ->(src) { valid_source?(src) }}
        end

        # Validate that the source attribute is an absolute URI or file and not
        # an not empty string.
        #
        # @param [String]
        #
        # @return [Boolean]
        #
        def valid_source?(source)
          absolute_uri?(source) ? true : ::File.exist?(source)
        end

        # Boolean, true if source is an absolute URI, false otherwise.
        #
        # @param [String] source
        #
        # @return [Boolean]
        #
        def absolute_uri?(source)
          source =~ URI::ABS_URI && URI.parse(source).absolute?
        rescue URI::InvalidURIError
          false
        end

        # Hook called when module is included.
        #
        # @param [Module] descendant
        #   The including module or class.
        #
        # @return [self]
        #
        # @api private
        def included(descendant)
          super
          descendant.extend ClassMethods
        end
      end

      extend ClassMethods
    end
  end
end
