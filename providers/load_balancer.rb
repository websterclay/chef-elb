include WebsterClay::Aws::Elb

# TODO: error handling
# TODO: count instances in each zone and warn if not equal
# TODO: warn if only one availability zone

def load_current_resource

  @current_lb = load_balancer_by_name(new_resource.lb_name)

  @current_resource = Chef::Resource::ElbLoadBalancer.new(new_resource.lb_name)
  @current_resource.lb_name(new_resource.lb_name)
  @current_resource.aws_access_key(new_resource.aws_access_key)
  @current_resource.aws_secret_access_key(new_resource.aws_secret_access_key)
  @current_resource.region(new_resource.region)
  @current_resource.listeners(new_resource.listeners)
  @current_resource.timeout(new_resource.timeout)

  if @current_lb
    @current_resource.availability_zones(@current_lb['AvailabilityZones'])
    @current_resource.instances(@current_lb['Instances'])
  end
  @current_resource.availability_zones || @current_resource.availability_zones([])
  @current_resource.instances || @current_resource.instances([])

  if new_resource.instances.nil? && new_resource.search_query
    new_resource.instances(search(:node, new_resource.search_query).map { |n| n['ec2']['instance_id']})
  end

  all_zones = availability_zone_for_instances(new_resource.instances)
  unique_zones = all_zones.compact.uniq

  if new_resource.availability_zones.nil?
    new_resource.availability_zones(unique_zones)
  end
end

action :create do
  ruby_block "Create ELB #{new_resource.lb_name}" do
    block do
      elb.create_load_balancer(new_resource.availability_zones, new_resource.lb_name, new_resource.listeners)
      data = nil
      begin
        Timeout::timeout(new_resource.timeout) do
          while true
            data = load_balancer_by_name(new_resource.lb_name)
            break if data
            sleep 3
          end
        end
      rescue Timeout::Error
        raise "Timed out waiting for ELB data after #{new_resource.timeout} seconds"
      end
      node.set[:elb][new_resource.lb_name] = data
      node.save if !Chef::Config.solo
    end
    action :create
    not_if do
      if data = load_balancer_by_name(new_resource.lb_name)
        node.set[:elb][new_resource.lb_name] = data
        node.save if !Chef::Config.solo
        true
      else
        false
      end
    end
  end
  new_resource.updated_by_last_action(true)

  configure_successful = false
  ruby_block "Configure ELB #{new_resource.lb_name}" do
    block do
      response = elb.configure_health_check(new_resource.lb_name, new_resource.health_check.first)
      if response.status != 200
        Chef::Log::fatal!("Configuring load balancer health check returned " << response.status.to_s)
      else
        Chef::Log::debug("Configure load balancer health check succeeded: \n" << response.body.to_s)
        configure_successful = true
      end
    end
    action :create
  end
  new_resource.updated_by_last_action(configure_successful)

  instances_to_add = new_resource.instances - current_resource.instances
  instances_to_delete = current_resource.instances - new_resource.instances

  instances_to_add.each do |instance_to_add|
    ruby_block "Register instance #{instance_to_add} with ELB #{new_resource.lb_name}" do
      block do
        elb.register_instances_with_load_balancer([instance_to_add], new_resource.lb_name)
        node.set[:elb][new_resource.lb_name] = load_balancer_by_name(new_resource.lb_name)
        node.save if !Chef::Config.solo
      end
      action :create
    end
    new_resource.updated_by_last_action(true)
  end

  instances_to_delete.each do |instance_to_delete|
    ruby_block "Deregister instance #{instance_to_delete} from ELB #{new_resource.lb_name}" do
      block do
        elb.deregister_instances_from_load_balancer([instance_to_delete], new_resource.lb_name)
        node.set[:elb][new_resource.lb_name] = load_balancer_by_name(new_resource.lb_name)
        node.save if !Chef::Config.solo
      end
      action :create
    end
    new_resource.updated_by_last_action(true)
  end

  zones_to_add = new_resource.availability_zones - current_resource.availability_zones
  zones_to_delete = current_resource.availability_zones - new_resource.availability_zones

  zones_to_add.each do |zone_to_add|
    ruby_block "Enabling Availability Zone #{zone_to_add} for ELB #{new_resource.lb_name}" do
      block do
        elb.enable_availability_zones_for_load_balancer([zone_to_add], new_resource.lb_name)
        node.set[:elb][new_resource.lb_name] = load_balancer_by_name(new_resource.lb_name)
        node.save if !Chef::Config.solo
      end
      action :create
    end
    new_resource.updated_by_last_action(true)
  end

  zones_to_delete.each do |zone_to_delete|
    ruby_block "Disable Availability Zone #{zone_to_delete} for ELB #{new_resource.lb_name}" do
      block do
        elb.disable_availability_zones_for_load_balancer([zone_to_delete], new_resource.lb_name)
        node.set[:elb][new_resource.lb_name] = load_balancer_by_name(new_resource.lb_name)
        node.save if !Chef::Config.solo
      end
      action :create
    end
    new_resource.updated_by_last_action(true)
  end

end

action :delete do
  ruby_block "Delete ELB #{new_resource.lb_name}" do
    block do
      elb.delete_load_balancer(new_resource.lb_name)
      node.set[:elb][new_resource.lb_name] = nil
      node.save if !Chef::Config.solo
    end
    action :create
    not_if do
      !!!load_balancer_by_name(new_resource.lb_name)
    end
  end
end