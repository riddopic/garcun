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
  # More sweetness syntactical sugar for our Pâtissier.
  #
  module ChefHelpers
    # Methods are also available as module-level methods as well as a mixin.
    extend self

    include Chef::Mixin::ShellOut

    def chef_run_context
      ::Chef::RunContext.new(chef_node, nil, nil)
    end

    def chef_node
      node = ::Chef::Node.new
      node.consume_external_attrs(nil, ohai)
      node
    end

    # Boolean indicating if the given Ruby Gem is installed.
    #
    # @param [String] gem
    #   The name of the Ruby Gem to check for.
    #
    # @return [Boolean]
    #   True if the Ruby Gem is installed, otherwise false.
    #
    def gem_installed?(gem = name)
      Gem::Specification.find_all_by_name(gem).blank? ? false : true
    end

    # Search for a matching node by a given role or tag.
    #
    # @param [Symbol] type
    #   The filter type, can be `:role` or `:tag`.
    #
    # @param [String] filter
    #   The role or tag to filter on.
    #
    # @param [Boolean] single
    #   True if we should return only a single match, or false to return all
    #   of the matches.
    #
    # @yield an optional block to enumerate over the nodes.
    #
    # @return [Array, Proc]
    #   The value of the passed block or node.
    #
    # @api public
    def find_by(type, filter, single = true, &block)
      nodes = []
      env   = node.chef_environment
      type  = Inflections.pluralize(type.to_s)

      if node.public_send(type).include? filter
        nodes << node
      end
      if !single || nodes.empty?
        search(:node, "#{type}:#{filter} AND chef_environment:#{env}") do |n|
          nodes << n
        end
      end

      if block_given?
        nodes.each { |n| yield n }
      else
        single ? [nodes.first] : nodes
      end
    end

    # Search for a matching node by role.
    #
    # @param [String] role
    #   The role to filter on.
    #
    # @param [Boolean] single
    #   True if we should return only a single match, or false to return all
    #   of the matches.
    #
    # @yield an optional block to enumerate over the nodes.
    #
    # @return [Array, Proc]
    #   The value of the passed block or node.
    #
    # @api public
    def find_by_role(role, single = true, &block)
      find_matching :role, role, single, block
    end

    # Search for a matching node by tag.
    #
    # @param [String] tag
    #   The role or tag to filter on.
    #
    # @param [Boolean] single
    #   True if we should return only a single match, or false to return all
    #   of the matches.
    #
    # @yield an optional block to enumerate over the nodes.
    #
    # @return [Array, Proc]
    #   The value of the passed block or node.
    #
    # @api public
    def find_by_tag(tag, single = true, &block)
      find_matching :tag, tag, single, block
    end

    alias_method :find_matching,      :find_by
    alias_method :find_matching_role, :find_by_role
    alias_method :find_matching_tag,  :find_by_tag

    # Adds a `run_now` method onto Resources so you can immediately execute
    # the resource block. This is a shortcut so you do not have to set the
    # action to :nothing, and then use the `.run_action` method with the
    # desired action.
    #
    # @example
    #     service 'sshd' do
    #       action [:enable, :start]
    #     end.run_now
    #
    def run_now(resource = nil)
      resource ||= self
      actions = Array(resource.action)
      Chef::Log.debug "Immediate execution of #{resource.name} #{actions}"
      resource.action(:nothing)
      actions.each { |action| resource.run_action(action) }
    end

    # Returns true if the current node is a docker container, otherwise
    # false.
    #
    # @return [Boolean]
    #
    # @api public
    def docker?
      ::File.exist?('/.dockerinit') || ::File.exist?('/.dockerenv')
    end

    # Returns true if the current node has selinux enabled, otherwise false.
    #
    # @return [Boolean]
    #
    # @api public
    def selinux?
      if installed?('getenforce')
        Mixlib::ShellOut.new('getenforce').run_command.stdout != "Disabled\n"
      else
        false
      end
    end

    # Retrieve the version number of the cookbook in the run list.
    #
    # @param name [String]
    #   name of cookbook to retrieve the version on.
    #
    # @return [Integer]
    #   version of the cookbook.
    #
    # @api public
    def cookbook_version(name = nil)
      cookbook = name.nil? ? cookbook_name : name
      node.run_context.cookbook_collection[cookbook].metadata.version
    end

    # Shortcut to return cache path, if you pass in a file it will return
    # the file with the cache path.
    #
    # @example
    #   file_cache_path
    #     => "/var/chef/cache/"
    #
    #   file_cache_path 'patch.tar.gz'
    #     => "/var/chef/cache/patch.tar.gz"
    #
    #   file_cache_path "#{node[:name]}-backup.tar.gz"
    #     => "/var/chef/cache/c20d24209cc8-backup.tar.gz"
    #
    # @param [String] args
    #   name of file to return path with file
    #
    # @return [String]
    #
    # @api public
    def file_cache_path(*args)
      if args.nil?
        Chef::Config[:file_cache_path]
      else
        ::File.join(Chef::Config[:file_cache_path], args)
      end
    end

    # Invokes the public method whose name goes as first argument just like
    # `public_send` does, except that if the receiver does not respond to
    # it the call returns `nil` rather than raising an exception.
    #
    # @note `_?` is defined on `Object`. Therefore, it won't work with
    # instances of classes that do not have `Object` among their ancestors,
    # like direct subclasses of `BasicObject`.
    #
    # @param [String] object
    #   The object to send the method to.
    #
    # @param [Symbol] method
    #   The method to send to the object.
    #
    # @api public
    def _?(*args, &block)
      if args.empty? && block_given?
        yield self
      else
        resp = public_send(*args[0], &block) if respond_to?(args.first)
        return nil if resp.nil?
        !!resp == resp ? args[1] : [args[1], resp]
      end
    end

    # Checks for existence of a cookbook file or template source in a cookbook.
    #
    # @example
    #   has_source?("foo.erb", :templates)
    #   has_source?("bar.conf", :files, "a_cookbook")
    #
    # @param [String] source
    #   Name of the desired template or cookbook file source.
    #
    # @param [Symbol] segment
    #   One of `:files` or `:templates`.
    #
    # @param [String, Nil] cookbook
    #   The name of the cookbook to look in, defaults to current cookbook.
    #
    # @return [String, Nil]
    #   Full path to the source or nil if it doesn't exist.
    #
    def has_source?(source, segment, cookbook = nil)
      cookbook ||= cookbook_name
      begin
        run_context.cookbook_collection[cookbook].send(
          :find_preferred_manifest_record, run_context.node, segment, source
        )
      rescue Chef::Exceptions::FileNotFound
        nil
      end
    end

    # Returns a hash using col1 as keys and col2 as values.
    #
    # @example zip_hash([:name, :age, :sex], ['Earl', 30, 'male'])
    #   => { :age => 30, :name => "Earl", :sex => "male" }
    #
    # @param [Array] col1
    #   Containing the keys.
    #
    # @param [Array] col2
    #   Values for hash.
    #
    # @return [Hash]
    #
    def zip_hash(col1, col2)
      col1.zip(col2).inject({}) { |r, i| r[i[0]] = i[1]; r }
    end

    # Amazingly and somewhat surprisingly comma separate a number
    #
    # @param [Integer] num
    #
    # @return [String]
    #
    # @api public
    def comma_separate(num)
      num.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end

    # Creates a temp directory executing the block provided. When done the
    # temp directory and all it's contents are garbage collected.
    #
    # @yield [Proc] block
    #   A block that will be run
    #
    # @return [Object]
    #   Result of the block operation
    #
    # @api public
    def with_tmp_dir(&block)
      Dir.mktmpdir(SecureRandom.hex(3)) do |tmp_dir|
        Dir.chdir(tmp_dir, &block)
      end
    end

    # Boolean method to check if a command line utility is installed.
    #
    # @param [String] cmd
    #   The command to find.
    #
    # @return [TrueClass, FalseClass]
    #   true if the command is found in the path.
    #
    def installed?(cmd)
      !Garcon::FileHelper.which(cmd).nil?
    end

    # Boolean method to check if a package is installed.
    #
    # @param [String] pkg
    #   The package to check for.
    #
    # @return [TrueClass, FalseClass]
    #   True if the package is found in the path.
    #
    def pkg_installed?(pkg)
      if node.platform_family == 'debian'
        shell_out("dpkg -l #{pkg}").exitstatus == 0 ? true : false
      elsif node.platform_family == 'rhel'
        shell_out("rpm -qa | grep #{pkg}").exitstatus == 0 ? true : false
      end
    end

    # @return [String] object inspection
    # @api public
    def inspect
      instance_variables.inject([
        "\n#<#{self.class}:0x#{self.object_id.to_s(16)}>",
        "\tInstance variables:"
      ]) do |result, item|
        result << "\t\t#{item} = #{instance_variable_get(item)}"
        result
      end.join("\n")
    end

    # @return [String] string of instance
    # @api public
    def to_s
      "<#{self.class}:0x#{self.object_id.to_s(16)}>"
    end
  end
end
