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
  # Library routine that returns an encrypted data bag value for a supplied
  # string. The key used in decrypting the encrypted value should be located
  # at node[:garcon][:secret][:key_path].
  #
  # Note that if node[:garcon][:devmode] is true, then the value of the index
  # parameter is just returned as-is. This means that in developer mode, if a
  # cookbook does this:
  #
  # @example
  #   class Chef
  #     class Recipe
  #       include Garcon::SecretBag
  #     end
  #   end
  #
  #   admin = secret('bag_name', 'RoG+3xqKE23uc')
  #
  # That means admin will be 'RoG+3xqKE23uc'
  #
  # You also can provide a default password value in developer mode, like:
  #
  #   node.set[:garcon][:secret][:passwd] = 'mysql_passwd'
  #   mysql_passwd = secret('passwords', 'eazypass')
  #
  #   The mysql_passwd will == 'eazypass'
  #
  module SecretBag
    include Garcon::Exceptions

    def secret(bag_name, index)
      if node[:garcon][:devmode]
        dev_secret(index)
      else
        case node[:garcon][:databag_type]
        when :encrypted
          encrypted_secret(bag_name, index)
        when :standard
          standard_secret(bag_name, index)
        when :vault
          vault_secret('vault_' + bag_name, index)
        else
          raise InvalidDataBagType
        end
      end
    end

    def encrypted_secret(bag_name, index)
      key_path = node[:garcon][:secret][:key_path]
      Chef::Log.info "Loading encrypted databag #{bag_name}.#{index} " \
                     "using key at #{key_path}"
      secret = Chef::EncryptedDataBagItem.load_secret key_path
      Chef::EncryptedDataBagItem.load(bag_name, index, secret)[index]
    end

    def standard_secret(bag_name, index)
      Chef::Log.info "Loading databag #{bag_name}.#{index}"
      Chef::DataBagItem.load(bag_name, index)[index]
    end

    def vault_secret(bag_name, index)
      begin
        require 'chef-vault'
      rescue LoadError
        Chef::Log.warn "Missing gem 'chef-vault'"
      end
      Chef::Log.info "Loading vault secret #{index} from #{bag_name}"
      ChefVault::Item.load(bag_name, index)[index]
    end

    # Return a password using either data bags or attributes for storage.
    # The storage mechanism used is determined by the
    # `node[:garcon][:use_databags]` attribute.
    #
    # @param [String] type
    #   password type, can be `:user`, `:service`, `:db` or `:token`
    #
    # @param [String] keys
    #   the identifier of the password
    #
    def get_password(type, key)
      unless [:db, :user, :service, :token].include?(type)
        Chef::Log.error "Unsupported type for get_password: #{type}"
        return
      end

      if node[:garcon][:use_databags]
        if type == :token
          secret node[:garcon][:secret][:secrets_data_bag], key
        else
          secret node[:garcon][:secret]["#{type}_passwords_data_bag"], key
        end
      else
        node[:garcon][:secret][key][type]
      end
    end

    # Loads the encrypted data bag item and returns credentials for the
    # environment or for a default key.
    #
    # @param [String] environment
    #   The environment
    #
    # @param [String] source
    #   The deployment source to load configuration for
    #
    # @return [Chef::DataBagItem]
    #   The data bag item
    #
    def data_bag_config_for(environment, source)
      data_bag_item = encrypted_data_bag_for(environment, DATA_BAG)

      if data_bag_item.has_key?(source)
        data_bag_item[source]
      elsif DATA_BAG == source
        data_bag_item
      else
        {}
      end
    end

    # Looks for the given data bag in the cache and if not found, will load a
    # data bag item named for the chef_environment, or '_wildcard' value.
    #
    # @param [String] environment
    #   The environment.
    #
    # @param [String] data_bag
    #   The data bag to load.
    #
    # @return [Chef::Mash]
    #   The data bag item in Mash form.
    #
    def encrypted_data_bag_for(environment, data_bag)
      @encrypted_data_bags = {} unless @encrypted_data_bags

      if encrypted_data_bags[data_bag]
        return get_from_data_bags_cache(data_bag)
      else
        data_bag_item = encrypted_data_bag_item(data_bag, environment)
        data_bag_item ||= encrypted_data_bag_item(data_bag, WILDCARD)
        data_bag_item ||= {}
        @encrypted_data_bags[data_bag] = data_bag_item
        return data_bag_item
      end
    end

    # @return [Hash]
    def encrypted_data_bags
      @encrypted_data_bags
    end

    # Loads an entry from the encrypted_data_bags class variable.
    #
    # @param [String] dbag
    #   The data bag to find.
    #
    # @return [type] [description]
    #
    def get_from_data_bags_cache(data_bag)
      encrypted_data_bags[data_bag]
    end

    # Loads an EncryptedDataBagItem from the Chef server and
    # turns it into a Chef::Mash, giving it indifferent access. Returns
    # nil when a data bag item is not found.
    #
    # @param [String] dbag
    # @param [String] dbag_item
    #
    # @raise [Chef::Garcon::DataBagEncryptionError]
    #   When the data bag cannot be decrypted or transformed into a Mash for
    #   some reason.
    #
    # @return [Chef::Mash]
    #
    def encrypted_data_bag_item(dbag, dbag_item)
      Mash.from_hash(Chef::EncryptedDataBagItem.load(dbag, dbag_item).to_hash)
    rescue Net::HTTPServerException
      nil
    rescue NoMethodError
      raise DataBagEncryptionError.new
    end
  end
end
