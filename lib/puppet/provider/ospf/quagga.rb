Puppet::Type.type(:ospf).provide :quagga do
  @doc = %q{Manages ospf parameters using quagga}

  @resource_map = {
    :router_id           => 'ospf router-id',
    :opaque              => 'capability opaque',
    :rfc1583             => 'compatible rfc1583',
    :abr_type            => 'ospf abr-type',
    :reference_bandwidth => 'auto-cost  reference-bandwidth',
    :default_information => 'default-information',
    :network             => 'network',
    :redistribute        => 'redistribute',
  }

  @default_values = {
    :abr_type => 'cisco',
  }

  @known_booleans = [ :opaque, :rfc1583, ]
  @known_arrays = [ :network, :redistribute, ]

  commands :vtysh => 'vtysh'

  def initialize value={}
    super(value)
    @property_flush = {}
  end

  def self.instances
    debug 'Create an instance of the OSPF process'
    found_section = false
    ospf = []
    hash = {}
    config = vtysh('-c', 'show running-config')
    config.split(/\n/).collect do |line|
      next if line =~ /\A!\Z/
      if line =~ /\Arouter (ospf)\Z/
        as = $1
        found_section = true
        hash[:ensure] = :present
        hash[:name] = as.to_sym
        hash[:provider] = self.name
      elsif line =~ /\A\w/ and found_section
        break
      elsif found_section
        config_line = line.strip
        @resource_map.each do |property, command|
          if config_line.start_with? command
            if @known_booleans.include? property
              hash[property] = :true
            elsif @known_arrays.include? property
              hash[property] ||= []
              config_line.slice! command
              hash[property] << config_line.strip
              hash[property].sort!
            else
              config_line.slice! command
              hash[property] = config_line.strip
            end
          end
        end
      end
    end

    @default_values.each do |property, value|
      unless hash.include? property
        hash[property] = value
      end
    end

    ospf << new(hash) unless hash.empty?
    ospf
  end

  def self.prefetch(resources)
    providers = instances
    found_providers = []
    resources.keys.each do |name|
      if provider = providers.find { |provider| provider.name == name }
        resources[name].provider = provider
        found_providers << provider
        provider.purge
      end
    end
    (providers - found_providers).each do |provider|
      provider.destroy
    end
  end

  def create
    debug 'Starting the OSPF process'
    @property_flush[:ensure] = :present
  end

  def destroy
    debug 'Stopping the OSPF process'
    @property_flush[:ensure] = :absent
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def flush
    debug 'Flushing changes'

    resource_map = self.class.instance_variable_get('@resource_map')

    cmds = []
    cmds << "configure terminal"
    cmds << "router ospf"

    if @property_flush[:ensure] == :absent
      remove
      @property_flush.clear
      @property_hash.clear
      return
    end

    @property_flush.each do |property, value|
      if resource_map.include? property
        old_value = @property_hash[property]

        if property == :network
          (old_value - value).each do |line|
            cmds << "no network #{line}"
          end
          (value - old_value).each do |line|
            cmds << "network #{line}"
          end

        elsif property == :redistribute
          (old_value - value).each do |line|
            cmds << "no redistribute #{line.split(/\s/).first}"
          end
          (value - old_value).each do |line|
            cmds << "redistribute #{line}"
          end

        else
          cmds << "#{resource_map[property]} #{value}"
        end
      end
      @property_hash[property] = value
    end
    @property_flush.clear

    cmds << "end"
    cmds << "write memory"
    vtysh(cmds.reduce([]){ |cmds, cmd| cmds << '-c' << cmd })
  end

  def purge
    debug 'Removing unused parameters'

    resource_map = self.class.instance_variable_get('@resource_map')
    needs_purge = false

    cmds = []
    cmds << "configure terminal"
    cmds << "router ospf"
    @property_hash.each do |property, value|
      unless @resource.include? property
        cmds << "no #{resource_map[property]}"
        needs_purge = true
      end
    end
    cmds << "end"
    cmds << "write memory"

    vtysh(cmds.reduce([]){ |cmds, cmd| cmds << '-c' << cmd }) if needs_purge
  end

  def remove
    cmds = []
    cmds << 'configure terminal'
    cmds << 'no router ospf'
    cmds << 'end'
    cmds << 'write memory'

    vtysh(cmds.reduce([]){ |cmds, cmd| cmds << '-c' << cmd })
  end

  @resource_map.keys.each do |property|
    if @known_booleans.include?(property)
      define_method "#{property}" do
        @property_hash[property] || :false
      end
    else
      define_method "#{property}" do
        @property_hash[property] || :absent
      end
    end

    define_method "#{property}=" do |value|
      @property_flush[property] = value
    end
  end
end