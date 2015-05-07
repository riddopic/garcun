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
  # Expand a path with late-evaluated segments.
  # Calls expand_path -- '~' becomes $HOME, '..' is expanded, etc.
  #
  # @example
  #   A symbol represents a segment to expand
  #     Pathname.register_path(:conf_dir, '/etc/openldap')
  #     Pathname.path_to(:conf_dir)            # => '/etc/openldap'
  #     Pathname.path_to(:conf_dir, ldap.conf) # => '/etc/openldap/ldap.conf'
  #
  # @example
  #   References aren't expanded until they're read
  #     Pathname.register_path(:conf_dir, '/etc/openldap')
  #     Pathname.register_path(:ldap, :conf_dir, 'ldap.conf')
  #     Pathname.path_to(:ldap)                # => '/etc/openldap/ldap.conf'
  #
  # @example
  #   If we change the conf_dir, everything under it changes as well
  #     Pathname.register_path(:conf_dir, '~/.openldap.d')
  #     Pathname.path_to(:ldap)                # => '/root/openldap.d/ldap.conf'
  #
  # @exampl
  #   References can be relative, and can hold symbols themselves
  #     Pathname.register_path(:conf_dir, '/etc', :appname, :environment)
  #     Pathname.register_path(:appname, 'app_awesome')
  #     Pathname.register_path(:environment, 'dev')
  #     Pathname.path_to(:conf_dir)            # => '/etc/app_awesome/dev'
  #
  module Pathref
    ROOT_PATHS = Hash.new unless defined?(ROOT_PATHS)
    extend self

    # @param [Array<[String,Symbol]>] pathsegs
    #   Any mixture of strings (literal sub-paths) and symbols (interpreted
    #   as references).
    #
    # @return [Pathname]
    #   A single expanded Pathname
    #
    # @api public
    def of(*pathsegs)
      relpath_to(*pathsegs).expand_path
    end
    alias_method :path_to, :of

    # @api public
    def register_path(handle, *pathsegs)
      ArgumentError.arity_at_least!(pathsegs, 1)
      ROOT_PATHS[handle.to_sym] = pathsegs
    end

    # @api public
    def register_paths(handle_paths = {})
      handle_paths.each_pair do |handle, pathsegs|
        register_path(handle, *pathsegs)
      end
    end

    # @api public
    def register_default_paths(handle_paths = {})
      handle_paths.each_pair do |handle, pathsegs|
        unless ROOT_PATHS.has_key?(handle.to_sym)
          register_path(handle, *pathsegs)
        end
      end
    end

    # @api public
    def unregister_path(handle)
      ROOT_PATHS.delete handle.to_sym
    end

    # Expand a path with late-evaluated segments @see `.path_to`. Calls
    # cleanpath (removing `//` double slashes and useless `..`s), but does not
    # reference the filesystem or make paths absolute.
    #
    # @api public
    def relpath_to(*pathsegs)
      ArgumentError.arity_at_least!(pathsegs, 1)
      pathsegs = pathsegs.flatten.map { |ps| expand_pathseg(ps) }.flatten
      self.new(File.join(*pathsegs)).cleanpath(true)
    end
    alias_method :relative_path_to, :relpath_to

    protected #      A T T E N Z I O N E   A R E A   P R O T E T T A

    # Recursively expand a path handle.
    #
    # @return [Array<String>]
    #   An array of path segments, suitable for .join
    #
    # @api public
    def expand_pathseg(handle)
      return handle unless handle.is_a?(Symbol)
      pathsegs = ROOT_PATHS[handle] or raise ArgumentError,
        "Don't know how to expand path reference '#{handle.inspect}'."
      pathsegs.map { |ps| expand_pathseg(ps) }.flatten
    end
  end
end

class Pathname
  extend Garcon::Pathref

  class << self; alias_method :new_pathname, :new; end

  # Like find, but returns an enumerable
  #
  def find_all
    Enumerator.new{|yielder| find{|path| yielder << path } }
  end

  def self.receive(obj)
    return obj if obj.nil?
    obj.is_a?(self) ? obj : new(obj)
  end

  # @return [Pathname]
  #   The basename without extension (using self.extname as the extension).
  #
  # @api public
  def corename
    basename(self.extname)
  end

  # @return [String]
  #   Compact string rendering
  #
  # @api public
  def inspect_compact() to_path.dump ; end

  alias_method :to_str, :to_path
end
