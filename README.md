Chef Helpers
============

This cookbook handles configuring Elastic Load Balancers at AWS

Installation
------------

The easiest way to install this is to use [knife-github-cookbooks](https://github.com/websterclay/knife-github-cookbooks):

    gem install knife-github-cookbooks
    knife github cookbook install websterclay/chef-elb

Usage
-----

This cookbook is designed to be run on a single node in your infrastructure. I
have a role called the 'rooster' I assign to one node to coordinate AWS API
calls based on the presence of other nodes.

Put `recipe[elb]` in the runlist of your coordinating node to install the
required dependeicnes on that node. Then, in a recipe also in that node's
runlist:

    # Load your AWS credentials databag
    aws = data_bag_item("aws", "main")

    elb_load_balancer "http-frontend" do
      aws_access_key        aws['aws_access_key_id']
      aws_secret_access_key aws['aws_secret_access_key']
      search_query          "role:app"
      action :create
    end

This will automatically create a Elastic Load Balancer that listens on port
80 and forwards requests to all servers that match the specified search on
port 80. You can change those defaults by specifying the `listeners`
attribute:

    elb_load_balancer "http-frontend" do
      aws_access_key        aws['aws_access_key_id']
      aws_secret_access_key aws['aws_secret_access_key']
      search_query          "role:app"
      listeners             [{"InstancePort" => 8080, "Protocol" => "HTTP", "LoadBalancerPort" => 80}]
      action :create
    end

You can also specify the `region` attribute to change what region the ELB is
created in, or specify the `instances` manually if you don't want to use a
search:

    elb_load_balancer "ap-tcp-frontend" do
      aws_access_key        aws['aws_access_key_id']
      aws_secret_access_key aws['aws_secret_access_key']
      instances             ['i-xxxxx', 'i-xxxxx']
      region                'ap-southeast-1'
      listeners             [{"InstancePort" => 1234, "Protocol" => "TCP", "LoadBalancerPort" => 1234}]
      action :create
    end

You can also do SSL, but it's a little funky.

First, you have to [upload your cert](http://docs.amazonwebservices.com/ElasticLoadBalancing/latest/DeveloperGuide/index.html?US_SettingUpLoadBalancerHTTPSIntegrated.html).

Then setup your listeners array like so:

    elb_load_balancer "http-and-https" do
      aws_access_key        aws['aws_access_key_id']
      aws_secret_access_key aws['aws_secret_access_key']
      search_query          "chef_environment:#{node.chef_environment} AND role:my_ssl_app"
      listeners             [
        {
          "InstancePort"     => 80,
          "Protocol"         => "HTTP",
          "LoadBalancerPort" => 80
        },
        {
          "InstancePort"     => 80,
          "Protocol"         => "HTTPS",
          "LoadBalancerPort" => 443,
          "SSLCertificateId" => "arn:aws:iam::xxxxxxxx:server-certificate/YourCertName"
        }
      ]
      action :create
    end

This resource can't [update the
cert](http://docs.amazonwebservices.com/ElasticLoadBalancing/latest/DeveloperGuide/index.html?US_UpdatingLoadBalancerSSL.html)
ID for you yet because of missing support in Fog - it will only do that on ELB
creation, but you should update it to reflect reality.

Caveats
-------

The cookbook automates determining what availability zones your instances are
in and automatically registers the instances. ELB's distribute traffic equally
between all enabled Availibity Zones. It's up to you to confirm that your 
instance distribution is equal if you have instances on more than one AZ.

Resources
---------

[ELB Docs](http://aws.amazon.com/documentation/elasticloadbalancing/)

Author
------

Jesse Newland  
jesse@websterclay.com  
@jnewland  
jnewland on freenode  

License
-------

    Author:: Jesse Newland (<jesse@websterclay.com>)
    Copyright:: Copyright (c) 2011 Webster Clay, LLC
    License:: Apache License, Version 2.0

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.