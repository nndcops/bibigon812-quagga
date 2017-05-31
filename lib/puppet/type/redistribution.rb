Puppet::Type.newtype(:redistribution) do
  @doc = %q{

This type provides the capability to manage protocol redistributions within puppet.

Examples:

```puppet
redistribution { 'ospf::connected':
  metric      => 100,
  metric_type => 2,
  route_map   => WORD,
}

redistribution { 'bgp:65000:ospf':
  metric    => 100,
  route_map => WORD,
}
```

  }

  ensurable do
    desc %q{ Manage the state of this redistribution. The default action is `present`. }

    defaultto(:present)

    newvalues(:present) do
      provider.create
    end

    newvalues(:absent) do
      provider.destroy
    end
  end

  newparam(:name) do
    desc %q{ The name contains the main protocol, the id and the protocol for redistribution. }

    newvalues(/\Aospf::(kernel|connected|static|rip|isis|bgp)\Z/)
    newvalues(/\Abgp:\d+:(connected|kernel|ospf|rip|static)\Z/)
  end

  newproperty(:metric) do
    desc %q{ Metric for redistributed routes. }

    newvalues(/\A\d+\Z/)

    munge do |value|
      value.to_i
    end
  end

  newproperty(:metric_type) do
    desc %q{ OSPF exterior metric type for redistributed routes. }

    newvalues(/\A1\Z/)

    munge do |value|
      value.to_i
    end
  end

  newproperty(:route_map) do
    desc %q{ Route map reference. }

    newvalues(/\A\w+\Z/)

    munge do |value|
      value.to_s
    end
  end

  autorequire(:package) do
    case value(:provider)
      when :quagga
        %w{quagga}
      else
        []
    end
  end

  autorequire(:service) do
    protocol = value(:name).split(/:/).first
    case value(:provider)
      when :quagga
        [ 'zebra', protocol ]
      else
        []
    end
  end
end
