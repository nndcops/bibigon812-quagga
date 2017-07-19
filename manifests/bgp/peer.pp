define quagga::bgp::peer (
  Optional[Integer[1, 4294967295]] $local_as = undef,
  Optional[Integer[1, 4294967295]] $remote_as = undef,
  Boolean $passive = false,
  Optional[Variant[Boolean, String]] $peer_group = undef,
  Boolean $shutdown = false,
  Optional[String] $update_source = undef,
  Hash $address_families = {},
  Enum['present', 'absent'] $ensure = 'present',
) {
  unless defined(Class['quagga::bgp']) {
    fail('You must include the quagga::bgp base class before using any quagga::bgp defined resources.')
  }

  quagga_bgp_peer {$name:
    ensure        => $ensure,
    local_as      => $local_as,
    remote_as     => $remote_as,
    passive       => $passive,
    peer_group    => $peer_group,
    shutdown      => $shutdown,
    update_source => $update_source,
  }

  $address_families.each |String $address_family_name, Hash $address_family| {
    $route_maps = [
      $address_family['route_map_export'],
      $address_family['route_map_import'],
      $address_family['route_map_in'],
      $address_family['route_map_out'],
    ]
    $prefix_lists = [
      $address_family['prefix_list_in'],
      $address_family['prefix_list_out'],
    ]
    quagga_bgp_peer_address_family {"${name} ${address_family_name}":
      *         => $address_family,
      require   => Quagga_bgp_peer[$name],
      subscribe => [
        Quagga::Prefix_list[$prefix_lists],
        Quagga::Route_map[$route_maps],
      ],
    }
  }
}
