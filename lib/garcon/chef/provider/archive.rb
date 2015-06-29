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

require 'fileutils'
require 'garcon'
require 'find'

class Chef
  class Resource
    # Extracts an archive file by determining the extention of the file and
    # sending it unzip method or extract. The source can be a file path or
    # a URL, for the later the file is downloaded in the Chef cache path. By
    # default the archive file will not be deleted. To have Chef remove the
    # file after it has been extracted set `remove_after true` on the
    # resource.
    #
    # @example
    #   archive 'file.tar.gz' do
    #     source 'http://server.example.com/file.tar.gz'
    #     owner 'tomcat'
    #     group 'tomcat'
    #     overwrite true
    #     remove_after true
    #   end
    #
    class Archive < Chef::Resource
      include Garcon

      # Chef attributes
      identity_attr :path
      provides      :archive
      state_attrs   :checksum, :owner, :group, :mode

      # Actions
      actions  :zip, :extract
      default_action :extract

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
      attribute :options,
        kind_of: [String, Array, Symbol],
        default: Array.new
    end
  end

  class Provider
    class Archive < Chef::Provider
      include Chef::Mixin::EnforceOwnershipAndPermissions
      include Chef::DSL::IncludeRecipe
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
      # @return [Chef::Provider]
      #
      # @api private
      def load_current_resource
        @current_resource ||= Chef::Resource::Archive.new(r.name)
        @current_resource
      end

      def action_extract
        converge_by "Extracting #{r.source} to #{r.path}" do
          extract
          do_acl_changes
          ::File.unlink(cached_file) if r.remove_after
        end
        r.updated_by_last_action(true)
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

      def archive_formats
        %w[.zip .tar .gz .bz2 .tar.gz .tar.bz2]
      end

      # Extracts an archive file by determining the extention of the file and
      # sending it unzip method or extract. The source can be a file path or
      # a URL, for the later the file is downloaded in the Chef cache path. By
      # default the archive file will not be deleted. To have Chef remove the
      # file after it has been extracted set `remove_after true` on the
      # resource.
      #
      # @example
      #   archive 'file.tar.gz' do
      #     source 'http://server.example.com/file.tar.gz'
      #     remove_after true
      #   end
      #
      # @return[undefined]
      #
      def extract
        src = ::File.extname(::File.basename r.source)
        Chef::Log.warn ''
        Chef::Log.warn '- - - - - - - - - - - - - - - - - - - - - - - - - - - -'
        Chef::Log.warn "      The source file: #{r.source}"
        Chef::Log.warn "The file extention is: #{src}"
        Chef::Log.warn "Reckon it's a archive? #{archive_formats.include? src}"
        Chef::Log.warn "Whatcha going to do with that thing then?"
        Chef::Log.warn '- - - - - - - - - - - - - - - - - - - - - - - - - - - -'
        Chef::Log.warn ''

        if archive_formats.include? src
          if archive_formats.include?(src) && src =~ /^.zip$/i
            Chef::Log.warn "Unzip the mother fucker!"
          elsif src =~ /^(.tar.gz|.tar|.gz|.bz2|.tar.bz2)$/
            Chef::Log.warn "Liberate the archive!!!"
          else
            Chef::Log.warn "Fuck dude, can't do shit with it."
          end
        else
          Chef::Log.warn 'Aint for format I can fuck with dude, stick it'
        end
        Chef::Log.warn '- - - - - - - - - - - - - - - - - - - - - - - - - - - -'
        Chef::Log.warn ''
        Chef::Log.warn '- - - - - - - - - - - - - - - - - - - - - - - - - - - -'

        if archive_formats.include? src
          if src =~ /^.zip$/i
            Chef::Log.info "Extracting Zip file #{r.source} to #{r.path}"
          elsif src =~ /^(.tar.gz|.tar|.gz|.bz2|.tar.bz2)$/
            Chef::Log.info "Extracting archive file #{r.source} to #{r.path}"
            updated = extract(r.source, r.path, Array(r.options))
          end
        else
          Chef::Log.info "Copying cached file into #{r.path}"
          FileUtils.cp cached_file, r.path
        end
      end

      # Unzip the archive.
      #
      # @return[undefined]
      #
      def unzip
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

      def options_map
        {
          owner: ::Archive::EXTRACT_OWNER,
          permissions: ::Archive::EXTRACT_PERM,
          time: ::Archive::EXTRACT_TIME,
          no_overwrite: ::Archive::EXTRACT_NO_OVERWRITE,
          acl: ::Archive::EXTRACT_ACL,
          fflags: ::Archive::EXTRACT_FFLAGS,
          extended_information: ::Archive::EXTRACT_XATTR,
          xattr: ::Archive::EXTRACT_XATTR,
        }
      end

      # Extract a tar, gz, bz2 archives file.
      #
      # @return[undefined]
      #
      def extract
        require 'archive'
        r.options ||= Array.new
        r.options.collect! { |option| options_map[option] }.compact!
        Dir.chdir(r.path) do
          archive = ::Archive.new(cached_file)
          archive_files = archive.map { |entry| entry.path }
          existing, missing = archive_files.partition do |file|
            ::File.exist?(::File.join(r.path, file))
          end
          current_times = existing.reduce({}) do |times, file|
            times[file] = ::File.mtime(file)
            times
          end
          archive.extract(extract: r.options.reduce(:|))
          unless missing.empty?
            still_missing = missing.reject { |f| ::File.exist?(f) }
            return true if still_missing.length < missing.length
          end
          changed_files = current_times.select do |file, time|
            ::File.mtime(file) != time
          end

          return true unless changed_files.empty?
        end

        false
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

      # Safely install and require the zip Gem
      #
      # @return [undefined]
      #
      # @api private
      def __zip__
        __libarchive__
        require 'zip' unless defined?(Zip)
      rescue LoadError
        g = Chef::Resource::ChefGem.new('zip', run_context)
        g.compile_time(false) if respond_to?(:compile_time)
        g.run_action :install
        require 'zip'
      end

      # Install libarchive package and Gem.
      #
      # @return [undefined]
      #
      # @api private
      def __libarchive__
        recipe_eval do
          run_context.include_recipe 'build-essential::default'
        end

        p = Chef::Resource::Package.new('libarchive', run_context)
        p.only_if { node[:platform_family] == 'rhel' }
        p.run_action :install

        p = Chef::Resource::Package.new('libarchive-dev', run_context)
        p.package_name libarchive
        p.run_action :install

        g = Chef::Resource::ChefGem.new('libarchive-ruby', run_context)
        g.compile_time(false) if respond_to?(:compile_time)
        g.version '0.0.3'
        g.run_action :install
      rescue LoadError
        recipe_eval do
          run_context.include_recipe 'build-essential::default'
        end
        g.run_action :install
      end

      def libarchive
        node[:platform_family] == 'rhel' ? 'libarchive-devel' : 'libarchive-dev'
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
  resource: :archive,
  provider:  Chef::Provider::Archive
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :centos,
  resource: :archive,
  provider:  Chef::Provider::Archive
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :oracle,
  resource: :archive,
  provider:  Chef::Provider::Archive
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :redhat,
  resource: :archive,
  provider:  Chef::Provider::Archive
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :scientific,
  resource: :archive,
  provider:  Chef::Provider::Archive
)
