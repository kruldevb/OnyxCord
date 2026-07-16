# frozen_string_literal: true

require 'onyxcord'

describe 'Permission property-based tests' do
  # UTIL-0307: Generate random permission combinations and compare with
  # a reference implementation based on the official Discord pseudocode.
  def canonical
    OnyxCord::Permissions
  end

  def bit_for(name)
    canonical::BIT_MAP[name]
  end

  def random_permission_bits
    canonical::REGISTRY.each_with_object(0) do |(name, _), bits|
      bits |= bit_for(name) if rand < 0.3
    end
  end

  def random_channel_overwrite(role_id, allow_bits, deny_bits)
    double('overwrite',
           allow: OnyxCord::Permissions.new(allow_bits),
           deny: OnyxCord::Permissions.new(deny_bits))
  end

  # Reference implementation based on Discord pseudocode
  # https://docs.discord.com/developers/topics/permissions#permission-overwrites
  def reference_calc(action, everyone_base, role_bases, everyone_ow, role_ows, member_ow)
    mask = bit_for(action)
    # 1. Base
    base = everyone_base
    role_bases.each { |rb| base |= rb }

    is_set = (base & mask) != 0

    # 2. @everyone overwrite
    if everyone_ow
      is_set = true if (everyone_ow.allow.bits & mask) != 0
      is_set = false if (everyone_ow.deny.bits & mask) != 0
    end

    # 3. Role overwrites: deny first, then allow
    role_denies = 0
    role_allows = 0
    role_ows.each do |ow|
      role_denies |= (ow.deny.bits & mask)
      role_allows |= (ow.allow.bits & mask)
    end

    is_set = false if (role_denies & mask) != 0
    is_set = true  if (role_allows & mask) != 0

    # 4. Member overwrite
    if member_ow
      is_set = true if (member_ow.allow.bits & mask) != 0
      is_set = false if (member_ow.deny.bits & mask) != 0
    end

    is_set
  end

  context 'role permissions without overwrites' do
    it 'matches reference for random base permissions' do
      actions = %i[send_messages view_channel connect speak administrator kick_members]
      50.times do
        everyone_base = random_permission_bits
        role_bases = Array.new(rand(1..5)) { random_permission_bits }
        everyone_role = double('everyone role', id: 0, permissions: OnyxCord::Permissions.new(everyone_base))
        roles = role_bases.each_with_index.map { |bits, i| double("role_#{i}", id: i + 1, permissions: OnyxCord::Permissions.new(bits)) }

        calc = Class.new { include OnyxCord::PermissionCalculator; attr_accessor :server, :roles; def id; 999; end; def resolve_id; id; end; def owner?; false; end; def communication_disabled?; false; end }.new
        calc.server = double('server', everyone_role: everyone_role)
        calc.roles = roles

        channel = double('channel', permission_overwrites: {})
        actions.sample(2).each do |action|
          expected = reference_calc(action, everyone_base, role_bases, nil, [], nil)
          actual = calc.__send__(:defined_role_permission?, action, channel)
          expect(actual).to eq(expected),
            "Mismatch for #{action}: expected #{expected}, got #{actual}"
        end
      end
    end
  end

  context 'role permissions with channel overwrites' do
    it 'matches reference for random overwrites' do
      actions = %i[send_messages view_channel connect]
      50.times do
        everyone_base = random_permission_bits
        role_bases = Array.new(rand(1..3)) { random_permission_bits }
        everyone_ow_allow = random_permission_bits
        everyone_ow_deny = random_permission_bits
        role_allows = Array.new(rand(1..3)) { random_permission_bits }
        role_denies = Array.new(rand(1..3)) { random_permission_bits }

        everyone_role = double('everyone role', id: 0, permissions: OnyxCord::Permissions.new(everyone_base))
        roles = role_bases.each_with_index.map { |bits, i| double("role_#{i}", id: i + 1, permissions: OnyxCord::Permissions.new(bits)) }

        ow_hash = {
          0 => random_channel_overwrite(0, everyone_ow_allow, everyone_ow_deny)
        }
        roles.each_with_index do |role, i|
          ow_hash[role.id] = random_channel_overwrite(role.id, role_allows[i] || 0, role_denies[i] || 0)
        end
        channel = double('channel', permission_overwrites: ow_hash)

        calc = Class.new { include OnyxCord::PermissionCalculator; attr_accessor :server, :roles; def id; 999; end; def resolve_id; id; end; def owner?; false; end; def communication_disabled?; false; end }.new
        calc.server = double('server', everyone_role: everyone_role)
        calc.roles = roles

        actions.sample(1).each do |action|
          everyone_ow_obj = ow_hash[0]
          ref_role_ows = roles.map { |r| ow_hash[r.id] }
          expected = reference_calc(action, everyone_base, role_bases, everyone_ow_obj, ref_role_ows, nil)
          actual = calc.__send__(:defined_role_permission?, action, channel)
          expect(actual).to eq(expected),
            "Mismatch for #{action}: expected #{expected}, got #{actual}"
        end
      end
    end
  end
end
