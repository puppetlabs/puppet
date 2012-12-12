require 'puppet/util/network_device'

module Puppet::Util::NetworkDevice::IPCalc

  # This is a rip-off of authstore
  Octet = '(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])'
  IPv4 = "#{Octet}\.#{Octet}\.#{Octet}\.#{Octet}"
  IPv6_full    = "_:_:_:_:_:_:_:_|_:_:_:_:_:_::_?|_:_:_:_:_::((_:)?_)?|_:_:_:_::((_:){0,2}_)?|_:_:_::((_:){0,3}_)?|_:_::((_:){0,4}_)?|_::((_:){0,5}_)?|::((_:){0,6}_)?"
  IPv6_partial = "_:_:_:_:_:_:|_:_:_:_::(_:)?|_:_::(_:){0,2}|_::(_:){0,3}"
  IP = "#{IPv4}|#{IPv6_full}".gsub(/_/,'([0-9a-fA-F]{1,4})').gsub(/\(/,'(?:')

  def parse(value)
    case value
    when /^(#{IP})\/(\d+)$/  # 12.34.56.78/24, a001:b002::efff/120, c444:1000:2000::9:192.168.0.1/112
      [$2.to_i,IPAddr.new($1)]
    when /^(#{IP})$/           # 10.20.30.40,
      value = IPAddr.new(value)
      [bits(value.family),value]
    end
  end

  def bits(family)
    family == Socket::AF_INET6 ? 128 : 32
  end

  def fullmask(family)
    (1 << bits(family)) - 1
  end

  def mask(family, length)
    (1 << (bits(family) - length)) - 1
  end

  # returns ip address netmask from prefix length
  def netmask(family, length)
    IPAddr.new(fullmask(family) & ~mask(family, length) , family)
  end

  # returns an IOS wildmask
  def wildmask(family, length)
    IPAddr.new(mask(family, length) , family)
  end

  # returns ip address prefix length from netmask
  def prefix_length(netmask)
    mask_addr = netmask.to_i
    return 0 if mask_addr == 0
    length=32
    if (netmask.ipv6?)
      length=128
    end

    mask = mask_addr < 2**length ? length : 128

    mask.times do
        if ((mask_addr & 1) == 1)
            break
        end
        mask_addr = mask_addr >> 1
        mask = mask - 1
    end
    mask
  end

  def linklocal?(ip)
  end

end
