# windows_failover_cluster

Chef cookbook to install and configure a Windows Failover Cluster Server.

## Table of contents

1. [Usage](#usage)
1. [Attributes](#attributes)
1. [Recipes](#recipes)
1. [Resources](#resources)
1. [Versioning](#versioning)
1. [Contributing](#contributing)
1. [License and Author](#license-and-author)

## Usage

## Attributes

Attributes in this cookbook:

Name                                              | Types  | Description                                 | Default
------------------------------------------------- | ------ | --------------------------------------------| -------
`['windows_failover_cluster']['run_as_user']`     | String | Sets the default cluster user for resources | `nil`
`['windows_failover_cluster']['run_as_password']` | String | Sets the default cluster user password      | `nil`

Setting these attributes allows you skip the `run_as_user` and `run_as_password` properties when using this cookbook's resources.

## Recipes

This cookbook doesn't ship any recipes.

## Resources

### `windows_failover_cluster_node`

It creates a new Windows Failover Cluster or joins an existing cluster.

#### Actions

- `create` - (default) Creates a new Windows Failover Cluster.
- `join` - Joins a node to an existing cluster.

#### Syntax

```ruby
windows_failover_cluster_node 'name' do
  cluster_ip                 String # required when using :create action
  cluster_name               String # default value: 'name' unless specified
  install_tools              true, false # default value: true
  quorum_disk                String
  run_as_password            String # default value: node['windows_failover_cluster']['run_as_password']
  run_as_user                String # default value: node['windows_failover_cluster']['run_as_user']
  action                     Symbol # defaults to :create if not specified
end
```

#### Examples

Create a cluster:

```ruby
windows_failover_cluster_node 'Cluster1' do
  cluster_ip '192.168.10.10'
  quorum_disk 'Cluster Disk 1'
  action :create
end
```

Join an existing cluster:

```ruby
windows_failover_cluster_node 'Cluster1' do
  action :join
end
```

### `windows_failover_cluster_generic_service`

It creates a generic service for a Windows Failover Cluster.

#### Actions

- `create` - (default) Creates a new Windows Failover Cluster Generic Service.

#### Syntax

```ruby
windows_failover_cluster_generic_service 'name' do
  service_name               String # default value: 'name' unless specified
  checkpoint_key             [Array, String]
  role_name                  String # required
  run_as_password            String # default value: node['windows_failover_cluster']['run_as_password']
  run_as_user                String # default value: node['windows_failover_cluster']['run_as_user']
  service_ip                 String # required
  storage                    String
  action                     Symbol # defaults to :create if not specified
end
```

#### Examples

Create a generic cluster service:

```ruby
windows_failover_cluster_generic_service 'Service1' do
  role_name 'Role1'
  service_ip '192.168.10.20'
  storage 'Cluster Disk 1'
  action :create
end
```

## Versioning

This cookbook uses [Semantic Versioning 2.0.0](http://semver.org/).

Given a version number MAJOR.MINOR.PATCH, increment the:

- MAJOR version when you make functional cookbook changes,
- MINOR version when you add functionality in a backwards-compatible manner,
- PATCH version when you make backwards-compatible bug fixes.

## Contributing

We welcome contributed improvements and bug fixes via the usual work flow:

1. Fork this repository
1. Create your feature branch (`git checkout -b my-new-feature`)
1. Commit your changes (`git commit -am 'Add some feature'`)
1. Push to the branch (`git push origin my-new-feature`)
1. Create a new pull request

## License and Author

Authors and contributors:

- Author: Stephen Hoekstra (stephenhoekstra@gmail.com)

```text
Copyright 2018, Stephen Hoekstra <stephenhoekstra@gmail.com>
Copyright 2018, Schuberg Philis

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
