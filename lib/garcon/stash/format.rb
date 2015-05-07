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
    # Database format serializer and deserializer. You can create your own
    # implementation of this class and define your own database format!
    #
    # @api public
    class Format
      # Read database header from input stream
      #
      # @param [#read] input
      #   the input stream
      #
      # @return void
      #
      def read_header(input)
        raise 'Not a stash' if input.read(MAGIC.bytesize) != MAGIC
        ver = input.read(2).unpack('n').first
        raise "Expected stash version #{VERSION}, got #{ver}" if ver != VERSION
      end

      # Return database header as string
      #
      # @return [String] database file header
      #
      def header
        MAGIC + [VERSION].pack('n')
      end

      # Serialize record and return string.
      #
      # @param [Array] rec
      #   an array with [key, value] or [key] if the record is deleted
      #
      # @return [String] serialized record
      #
      def dump(rec)
        data = if rec.size == 1
          [rec[0].bytesize, DELETE].pack('NN') << rec[0]
        else
          [rec[0].bytesize, rec[1].bytesize].pack('NN') << rec[0] << rec[1]
        end
        data << crc32(data)
      end

      # Deserialize records from buffer, and yield them.
      #
      # @param [String] buf
      #   the buffer to read from
      #
      # @yield [Array] block
      #   deserialized record [key, value] or [key] if the record is deleted
      #
      # @return [Fixnum] number of records
      #
      def parse(buf)
        n, count = 0, 0
        while n < buf.size
          key_size, value_size = buf[n, 8].unpack('NN')
          data_size = key_size + 8
          data_size += value_size if value_size != DELETE
          data = buf[n, data_size]
          n += data_size
          unless buf[n, 4] == crc32(data)
            raise 'CRC mismatch: your stash might be corrupted!'
          end
          n += 4
          yield(value_size == DELETE ? [data[8, key_size]] : [data[8, key_size], data[8 + key_size, value_size]])
          count += 1
        end
        count
      end

      protected #      A T T E N Z I O N E   A R E A   P R O T E T T A

      # Magic string of the file header.
      MAGIC = 'ABRACADABRA'

      # Database file format version (it is a hash after all).
      VERSION = 420

      # Special value size used for deleted records
      DELETE = (1 << 32) - 1

      # Compute crc32 of string
      #
      # @param [String] s a string
      #
      # @return [Fixnum]
      #
      def crc32(s)
        [Zlib.crc32(s, 0)].pack('N')
      end
    end
  end
end
