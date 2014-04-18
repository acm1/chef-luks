#
# Cookbook Name:: luks
# Provider:: device
#
# Copyright 2013, Intoximeters, Inc
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


class Chef::Exceptions::LUKS < RuntimeError; end

action :create do
  if @current_resource.exists
    Chef::Log.info "#{@new_resource} already exists - nothing to do."
  else
    converge_by("Create #{@new_resource}") do
      luks_format_device
    end
  end
end

action :open do
  if @current_resource.open
    Chef::Log.info "#{@new_resource} is already open - nothing to do."
  else
    converge_by("Open #{@new_resource}") do
      luks_open_device
    end
  end
end

action :close do
  if @current_resource.open
    converge_by("Close #{@new_resource}") do
      luks_close_device
    end
  else
    Chef::Log.info "#{@new_resource} is not open - nothing to do."
  end
end

def whyrun_supported?
  true
end

def load_current_resource
  @current_resource = Chef::Resource::LuksDevice.new(@new_resource.name)
  @current_resource.key_file(@new_resource.key_file)
  @current_resource.luks_name(@new_resource.luks_name)

  if is_luks_device? @current_resource.block_device
    @current_resource.exists = true
  end

  if is_open? @current_resource.luks_name
    @current_resource.open = true
  end
end

def is_luks_device?(block_device)
  cmd = Mixlib::ShellOut.new(
    '/sbin/cryptsetup', 'isLuks', block_device
    ).run_command

  cmd.exitstatus == 0
end

def is_open?(name)
  cmd = Mixlib::ShellOut.new('/sbin/cryptsetup', '-q', 'status', name).run_command
  cmd.exitstatus == 0
end

def append_to_crypttab(block_device, luks_name, key_file, options={})
  ::File.open('/etc/crypttab', 'a') do |crypttab|
    crypttab.puts("#{luks_name}\t#{block_device}\t#{key_file}\tluks")
  end
end

def luks_open_device
  cmd = Mixlib::ShellOut.new(
    '/sbin/cryptsetup', '-q', '-d', new_resource.key_file, 'luksOpen',
    new_resource.block_device, new_resource.luks_name).run_command

  raise Chef::Exceptions::LUKS.new cmd.stderr if cmd.exitstatus != 0

  append_to_crypttab new_resource.block_device,
    new_resource.luks_name, new_resource.key_file
end

def luks_close_device
  cmd = Mixlib::ShellOut.new('/sbin/cryptsetup', '-q', 'luksClose', new_resource.luks_name).run_command

  raise Chef::Exceptions::LUKS.new cmd.stderr if cmd.exitstatus != 0

  editor = Chef::Util::FileEdit.new('/etc/crypttab')
  editor.search_file_delete_line(/^#{new_resource.luks_name}/)
  editor.write_file
end

def luks_format_device
  cmd = Mixlib::ShellOut.new(
    '/sbin/cryptsetup', '-q', 'luksFormat',
    new_resource.block_device, new_resource.key_file).run_command

  if cmd.exitstatus != 0
    raise Chef::Exceptions::LUKS.new cmd.stderr
  end
end
