actions :create, :delete

attribute :lb_name,               :kind_of => String, :name_attribute => true
attribute :aws_access_key,        :kind_of => String
attribute :aws_secret_access_key, :kind_of => String
attribute :region,                :kind_of => String, :default => 'us-east-1'
attribute :availability_zones,    :kind_of => Array
attribute :listeners,             :kind_of => Array,  :default => [{"InstancePort" => 80, "Protocol" => "HTTP", "LoadBalancerPort" => 80}]
attribute :instances,             :kind_of => Array
attribute :search_query,          :kind_of => String
attribute :timeout,                                   :default => 60