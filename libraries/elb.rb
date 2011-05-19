module WebsterClay
  module Aws
    module Elb
      def elb
        @@elb ||= Fog::AWS::ELB.new(
          :aws_access_key_id => new_resource.aws_access_key,
          :aws_secret_access_key => new_resource.aws_secret_access_key,
          :region => new_resource.region
        )
      end

      def ec2
        @@ec2 ||= Fog::Compute.new(:provider => 'AWS',
          :aws_access_key_id => new_resource.aws_access_key,
          :aws_secret_access_key => new_resource.aws_secret_access_key,
          :region => new_resource.region
        )
      end

      def load_balancer_by_name(name)
        elb.describe_load_balancers.body["DescribeLoadBalancersResult"]["LoadBalancerDescriptions"].detect { |lb| lb["LoadBalancerName"] == new_resource.lb_name }
      end

      def availability_zone_for_instances(instances)
        ec2.describe_instances('instance-id' => [*instances]).body['reservationSet'].map { |r| r['instancesSet'] }.flatten.map { |i| i['placement']['availabilityZone'] }
      end

    end
  end
end
    