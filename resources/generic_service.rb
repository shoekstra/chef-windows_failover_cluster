#
# Cookbook:: windows_failover_cluster
# Resource:: generic_service
#
# Copyright:: 2018, Stephen Hoekstra
# Copyright:: 2018, Schuberg Philis
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

require 'ipaddress'

property :service_name, [Array, String], name_property: true
property :checkpoint_key, [Array, String]
property :role_name, String, required: true
property :run_as_user, String, required: true, default: lazy { node['windows_failover_cluster']['run_as_user'] }, callbacks: { 'must not be nil' => ->(p) { !p.nil? } }
property :run_as_password, String, required: true, default: lazy { node['windows_failover_cluster']['run_as_password'] }, callbacks: { 'must not be nil' => ->(p) { !p.nil? } }
property :service_ip, String, required: true, callbacks: { 'must be a valid IP address' => ->(ip) { IPAddress.valid?(ip) } }
property :storage, String

default_action :create

action_class do
  def cluster_contain_node?
    powershell_out_with_options('(Get-ClusterNode).Name').stdout.split(/\r\n/).include? node['hostname']
  end

  def cluster_resources
    powershell_out_with_options('(Get-ClusterResource).Name').stdout.split(/\r\n/)
  end

  def powershell_out_options
    { user: new_resource.run_as_user, password: new_resource.run_as_password, domain: node['domain'] }
  end

  def powershell_out_with_options(script)
    powershell_out(script, powershell_out_options)
  end

  def powershell_out_with_options!(script)
    powershell_out!(script, powershell_out_options)
  end

  def service_display_name
    powershell_out_with_options("(Get-Service #{new_resource.service_name}).DisplayName").stdout.chomp
  end

  def cluster_group
    powershell_out_with_options("(Get-ClusterGroup -name #{new_resource.role_name}).Name").stdout.chomp
  end

  def to_array(var)
    var = var.is_a?(Array) ? var : [var]
    var = var.reject(&:nil?)
    var
  end
end

action :create do
  services = to_array(new_resource.service_name)
  unless cluster_group == ""
    log "Role: #{new_resource.role_name} already exists" do
      level :debug
    end
    return
  end

  # Create cluster role
  generic_service_script = "Add-ClusterGenericServiceRole -ServiceName '#{services[0]}' -Name '#{new_resource.role_name}'"
  generic_service_script << " -StaticAddress #{new_resource.service_ip}" if new_resource.service_ip
  generic_service_script << " -Storage \'#{new_resource.storage}\'" if new_resource.storage
  generic_service_script << " -CheckpointKey #{to_array(new_resource.checkpoint_key).map(&:inspect).join(', ')}" if new_resource.checkpoint_key

  powershell_out_with_options!(generic_service_script) if cluster_contain_node? && !cluster_resources.include?(service_display_name)

  # If more than one service add these to role
  if services.length > 1
    services.each_with_index do |s,i|
      next if i == 0
      generic_service_script = "Add-ClusterResource -Name '#{services[i]}' -ResourceType 'Generic Service' -Group '#{new_resource.role_name}'"
      powershell_out_with_options!(generic_service_script)

      generic_service_script = "Set-ClusterResourceDependency -Resource '#{services[i]}' -Dependency '[#{new_resource.role_name}]'"
      powershell_out_with_options!(generic_service_script)

      generic_service_script = "Get-ClusterResource -name '#{services[i]}' | Set-ClusterParameter -multiple @{'ServiceName'='#{services[i]}';'UseNetworkName'=1}"
      powershell_out_with_options!(generic_service_script)

      generic_service_script = "Start-ClusterResource -Name '#{services[i]}'"
      powershell_out_with_options!(generic_service_script)
    end
  end
end
