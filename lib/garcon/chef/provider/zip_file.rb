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

require 'garcon'
require 'find'

class Chef
  class Resource
    class ZipFile < Chef::Resource
      include Garcon

      # Chef attributes
      identity_attr :path
      provides      :zip_file
      state_attrs   :checksum, :owner, :group, :mode

      # Actions
      actions        :zip, :unzip
      default_action :unzip

      # Attributes
      attribute :path,
        kind_of: String,
        name_attribute: true
      attribute :source,
        kind_of: [String, URI::HTTP],
        callbacks: source_callbacks,
        required: true
      attribute :remove_after,
        kind_of: [TrueClass, FalseClass],
        default: false
      attribute :overwrite,
        kind_of: [TrueClass, FalseClass],
        default: false
      attribute :checksum,
        kind_of: String,
        regex:   /^[0-9a-f]{32}$|^[a-zA-Z0-9]{40,64}$/
      attribute :owner,
        kind_of: [String, Integer],
        regex:   Chef::Config[:user_valid_regex]
      attribute :group,
        kind_of: [String, Integer],
        regex:   Chef::Config[:group_valid_regex]
      attribute :mode,
        kind_of: Integer,
        regex:   /^0?\d{3,4}$/
      attribute :check_cert,
        kind_of: [TrueClass, FalseClass],
        default: true
      attribute :header,
        kind_of: String
    end
  end

  class Provider
    class ZipFile < Chef::Provider
      include Chef::Mixin::EnforceOwnershipAndPermissions
      include Garcon

      def initialize(new_resource, run_context)
        super
        __zip__ unless defined?(Zip)
      end

      # Shortcut to new_resource.
      #
      alias_method :r, :new_resource

      # Boolean indicating if WhyRun is supported by this provider.
      #
      # @return [TrueClass, FalseClass]
      #
      # @api private
      def whyrun_supported?
        true
      end

      # Load and return the current resource.
      #
      # @return [Chef::Provider::ZipFile]
      #
      # @api private
      def load_current_resource
        @current_resource ||= Chef::Resource::ZipFile.new(r.name)
        @current_resource
      end

      def action_unzip
        converge_by "Unzip #{r.source} to #{r.path}" do
          Zip::File.open(cached_file) do |zip|
            zip.each do |entry|
              path = ::File.join(r.path, entry.name)
              FileUtils.mkdir_p(::File.dirname(path))
              if r.overwrite && ::File.exist?(path) && !::File.directory?(path)
                FileUtils.rm(path)
              end
              zip.extract(entry, path)
            end
          end
          do_acl_changes
          ::File.unlink(cached_file) if r.remove_after
          r.updated_by_last_action(true)
        end
      end

      def action_zip
        if ::File.exists?(r.path) && !r.overwrite
          Chef::Log.info "#{r.path} already exists - nothing to do"
        else
          ::File.unlink(r.path) if ::File.exists?(r.path)
          if ::File.directory?(r.source)
            converge_by "Zip #{r.source}" do
              z = Zip::File.new(r.path, true)
              Find.find(r.source) do |f|
                next if f == r.source
                zip_fname = f.sub(r.source, '')
                z.add(zip_fname, f)
              end
              z.close
              do_acl_changes
              r.updated_by_last_action(true)
            end
          else
            Chef::Log.warn 'A valid directory must be specified for ziping.'
          end
        end
      end

      # Implementation components *should* follow symlinks when managing access
      # control (e.g., use chmod instead of lchmod even if the path we're
      # managing is a symlink).
      #
      def manage_symlink_access?
        false
      end

      private #   P R O P R I E T À   P R I V A T A   Vietato L'accesso

      # Change file ownership and mode
      #
      # @return [undefined]
      #
      # @api private
      def do_acl_changes
        if access_controls.requires_changes?
          converge_by(access_controls.describe_changes) do
            access_controls.set_all
          end
        end
      end

      # Ensure all prerequisite software is installed.
      #
      # @return [undefined]
      #
      # @api private
      def __zip__
        require 'zip' unless defined?(Zip)
      rescue LoadError
        g = Chef::Resource::ChefGem.new('zip', run_context)
        g.compile_time(false) if respond_to?(:compile_time)
        g.run_action(:install)
        require 'zip'
      end

      # Cache a file locally in Chef::Config[:file_cache_path].
      #
      # @note The file is gargbage collected at the end of a run.
      #
      # @return [String]
      #   Path to the cached file.
      #
      def cached_file
        if r.source =~ URI::ABS_URI &&
          %w[ftp http https].include?(URI.parse(r.source).scheme)
          file = ::File.basename(URI.unescape(URI.parse(r.source).path))
          cache_file_path = file_cache_path(file)

          d ||= Chef::Resource::Download.new(cache_file_path, run_context)
          d.backup      false
          d.source      r.source
          d.owner       r.owner      if r.owner
          d.group       r.group      if r.group
          d.header      r.header     if r.header
          d.checksum    r.checksum   if r.checksum
          d.check_cert  r.check_cert
          d.run_action  :create
        else
          cache_file_path = r.source
        end

        cache_file_path
      end
    end
  end
end

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :amazon,
  resource: :zip_file,
  provider:  Chef::Provider::ZipFile
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :centos,
  resource: :zip_file,
  provider:  Chef::Provider::ZipFile
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :oracle,
  resource: :zip_file,
  provider:  Chef::Provider::ZipFile
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :redhat,
  resource: :zip_file,
  provider:  Chef::Provider::ZipFile
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :scientific,
  resource: :zip_file,
  provider:  Chef::Provider::ZipFile
)
