# encoding: UTF-8
#
# Author: Stefano Harding <riddopic@gmail.com>
#
# Copyright (C) 2014-2015 Stefano Harding
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
  module Stash
    module Serializer
      # Serializer which only encodes key in binary
      #
      # @api public
      class None
        # (see Stash::Serializer::Default#key_for)
        if ''.respond_to? :force_encoding
          def key_for(key)
            if key.encoding != Encoding::BINARY
              key = key.dup if key.frozen?
              key.force_encoding(Encoding::BINARY)
            end
            key
          end
        else
          def key_for(key)
            key
          end
        end

        # (see Stash::Serializer::Default#dump)
        def dump(value)
          value
        end

        # (see Stash::Serializer::Default#load)
        def load(value)
          value
        end
      end

      # Default serializer which converts keys to strings and marshalls values.
      #
      # @api public
      class Default < None
        # Transform the key to a string.
        #
        # @param [Object] key
        # @return [String]
        #   The key transformed to string.
        def key_for(key)
          super(key.to_s)
        end

        # Serialize a value.
        #
        # @param [Object] value
        # @return [String]
        #   The value transformed to string.
        def dump(value)
          Marshal.dump(value)
        end

        # Parse a value.
        #
        # @param [String] value
        # @return [Object]
        #   The deserialized value.
        def load(value)
          Marshal.load(value)
        end
      end
    end
  end
end
