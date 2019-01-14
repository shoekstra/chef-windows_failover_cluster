#
# Cookbook:: windows_failover_cluster
# Resource:: node
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

actions :create
default_action :create

property :cluster_name, String, name_property: true
property :cluster_ip, String, required: true, callbacks: { 'must be a valid IP address' => ->(ip) { IPAddress.valid?(ip) } }
property :install_tools, [TrueClass, FalseClass], required: false, default: true
property :quorum_disk, String, required: false
property :run_as_user, String, required: true, default: lazy { node['windows_failover_cluster']['run_as_user'] }, callbacks: { 'must not be nil' => ->(p) { !p.nil? } }
property :run_as_password, String, required: true, default: lazy { node['windows_failover_cluster']['run_as_password'] }, callbacks: { 'must not be nil' => ->(p) { !p.nil? } }

actions :create, :join

action_class do
  def cluster_contain_node?
    powershell_out_with_options('(Get-ClusterNode).Name').stdout.split(/\r\n/).include? node['hostname']
  end

  def cluster_exist?(cluster_name)
    powershell_out_with_options("(Get-Cluster #{cluster_name}).name").stdout.chomp == cluster_name
  end

  def cluster_quorum_disk?(disk_name)
    powershell_out_with_options('(Get-ClusterQuorum).QuorumResource.Name').stdout.chomp == disk_name
  end

  def install_windows_feature(feature)
    to_array(feature).each do |f|
      windows_feature f do
        install_method :windows_feature_powershell
        action :install
      end
    end
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

  def to_array(var)
    var = var.is_a?(Array) ? var : [var]
    var = var.reject(&:nil?)
    var
  end
end

action :create do
  # Install Failover Clustering feature and PowerShell module
  windows_features = %w(Failover-Clustering RSAT-Clustering-Powershell)
  windows_features << 'RSAT-Clustering-Mgmt' if new_resource.install_tools
  install_windows_feature(windows_features)
  # Create the cluster
  powershell_out_with_options!("New-Cluster -Name #{new_resource.cluster_name} -Node #{node['hostname']} -StaticAddress #{new_resource.cluster_ip} -Force") unless cluster_exist?(new_resource.cluster_name)
  # Add any available disks to the cluster
  powershell_out_with_options('Get-ClusterAvailableDisk | Add-ClusterDisk')
  # Set quorum to use node & disk majority
  powershell_out_with_options!("Set-ClusterQuorum -NodeAndDiskMajority \'#{new_resource.quorum_disk}\'") unless cluster_quorum_disk?(new_resource.quorum_disk)
end

action :join do
  # Install Failover Clustering feature and PowerShell module
  windows_features = %w(Failover-Clustering RSAT-Clustering-Powershell)
  windows_features << 'RSAT-Clustering-Mgmt' if new_resource.install_tools
  install_windows_feature(windows_features)
  # Join the cluster
  powershell_out_with_options!("Add-ClusterNode -Cluster #{new_resource.cluster_name} -Name #{node['hostname']}") if cluster_exist?(new_resource.cluster_name) && !cluster_contain_node?
end
