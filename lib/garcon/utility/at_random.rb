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

require 'securerandom'

module Garcon
  module AtRandom
    module ClassMethods
      def at_random(adjectives, nouns)
        build(random_seed, adjectives, nouns)
      end

      private

      def build(seed, adjectives, nouns)
        [ adjectives[seed % adjectives.length],
          nouns[seed % nouns.length]
        ].compact.map(&:capitalize).join(' ')
      end

      def random_seed
        SecureRandom.random_number(4096)
      end
    end

    def self.included(other)
      other.extend(ClassMethods)
    end

    extend ClassMethods
  end

  module Names
    include AtRandom
    ADJECTIVES = %w(autumn hidden bitter misty silent empty dry dark summer
      icy delicate quiet white cool spring winter patient twilight dawn crimson
      wispy weathered blue billowing broken cold damp falling frosty green long
      late lingering bold little morning muddy old red rough still small
      sparkling throbbing shy wandering withered wild black young holy solitary
      fragrant aged snowy proud floral restless divine polished ancient purple
      lively nameless)

    NOUNS = %w(waterfall river breeze moon rain wind sea morning snow lake
      sunset pine shadow leaf dawn glitter forest hill cloud meadow sun glade
      bird brook butterfly bush dew dust field fire flower firefly feather grass
      haze mountain night pond darkness snowflake silence sound sky shape surf
      thunder violet water wildflower wave water resonance sun wood dream cherry
      tree fog frost voice paper frog smoke star)
  end

  module Hacker
    include AtRandom
    ADJECTIVES = %w(auxiliary primary back-end digital open-source virtual
      cross-platform redundant online haptic multi-byte bluetooth wireless 1080p
      neural optical solid state mobile)

    NOUNS = %w(driver protocol bandwidth panel microchip program port card
      array interface system sensor firewall hard drive pixel alarm feed monitor
      application transmitter bus circuit capacitor matrix)
  end
end
