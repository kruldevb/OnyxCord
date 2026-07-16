# frozen_string_literal: true

require 'onyxcord'

describe OnyxCord::Permissions do
  subject { OnyxCord::Permissions.new }

  describe 'initialization and validation' do
    it 'initializes with 0 bits' do
      expect(subject.bits).to eq 0
    end

    it 'accepts an Integer' do
      expect(OnyxCord::Permissions.new(5).bits).to eq 5
    end

    it 'accepts a decimal String' do
      expect(OnyxCord::Permissions.new('5').bits).to eq 5
    end

    it 'accepts an Array of symbols' do
      instance = OnyxCord::Permissions.new %i[administrator manage_guild]
      expect(instance.bits & OnyxCord::Permissions::BIT_MAP[:administrator]).not_to eq 0
      expect(instance.bits & OnyxCord::Permissions::BIT_MAP[:manage_guild]).not_to eq 0
    end

    it 'accepts deprecated aliases in the Array form' do
      instance = OnyxCord::Permissions.new %i[manage_server use_external_emoji use_slash_commands]
      expect(instance.bits & OnyxCord::Permissions::BIT_MAP[:manage_guild]).not_to eq 0
      expect(instance.bits & OnyxCord::Permissions::BIT_MAP[:use_external_emojis]).not_to eq 0
      expect(instance.bits & OnyxCord::Permissions::BIT_MAP[:use_application_commands]).not_to eq 0
    end

    it 'rejects negative bits' do
      expect { OnyxCord::Permissions.new(-1) }.to raise_error(ArgumentError, /negative/)
    end

    it 'rejects non-numeric String silently converting to zero' do
      expect { OnyxCord::Permissions.new('abc') }.to raise_error(ArgumentError)
    end

    it 'rejects unknown symbol in array' do
      expect { OnyxCord::Permissions.new %i[administrator nonexistent] }
        .to raise_error(ArgumentError, /Unknown/)
    end

    it 'rejects invalid type' do
      expect { OnyxCord::Permissions.new({}) }.to raise_error(ArgumentError, /Expected/)
    end
  end

  describe '#bits=' do
    it 'updates the value and calls init_vars' do
      expect(subject).to receive(:init_vars)
      subject.bits = 1
      expect(subject.bits).to eq 1
    end

    it 'rejects negative bits' do
      expect { subject.bits = -1 }.to raise_error(ArgumentError, /negative/)
    end
  end

  describe '.bits' do
    it 'packs canonical names' do
      bits = OnyxCord::Permissions.bits(%i[administrator manage_guild])
      expect(bits).to eq(
        OnyxCord::Permissions::BIT_MAP[:administrator] |
        OnyxCord::Permissions::BIT_MAP[:manage_guild]
      )
    end

    it 'rejects unknown symbols' do
      expect { OnyxCord::Permissions.bits(%i[admin nonexistent]) }
        .to raise_error(ArgumentError, /Unknown/)
    end
  end

  describe '#defined_permissions' do
    it 'lists set flags' do
      instance = OnyxCord::Permissions.new(
        OnyxCord::Permissions::BIT_MAP[:administrator] |
        OnyxCord::Permissions::BIT_MAP[:manage_guild]
      )
      names = instance.defined_permissions
      expect(names).to include(:administrator, :manage_guild)
    end

    it 'returns empty for zero bits' do
      expect(subject.defined_permissions).to be_empty
    end

    it 'preserves unknown higher bits' do
      instance = OnyxCord::Permissions.new((1 << 100) | OnyxCord::Permissions::BIT_MAP[:administrator])
      names = instance.defined_permissions
      expect(names).to include(:administrator)
      expect(names.size).to eq 1
    end
  end

  describe '#permission? and #defined_permission?' do
    it 'returns true for set permissions' do
      instance = OnyxCord::Permissions.new(%i[send_messages])
      expect(instance.permission?(:send_messages)).to be true
    end

    it 'returns false for unset permissions' do
      expect(subject.permission?(:administrator)).to be false
    end

    it 'rejects unknown symbols' do
      expect { subject.permission?(:class) }.to raise_error(ArgumentError)
    end

    it 'rejects :bits as a permission name' do
      expect { subject.permission?(:bits) }.to raise_error(ArgumentError)
    end

    it 'rejects :object_id as a permission name' do
      expect { subject.permission?(:object_id) }.to raise_error(ArgumentError)
    end

    it 'rejects arbitrary string' do
      expect { subject.permission?('send') }.to raise_error(ArgumentError)
    end

    it 'works with deprecated aliases' do
      instance = OnyxCord::Permissions.new(%i[read_messages])
      expect(instance.permission?(:read_messages)).to be true
      expect(instance.permission?(:view_channel)).to be true
    end
  end

  describe '#can_* setters' do
    it 'sets a permission via canonical name' do
      subject.can_send_messages = true
      expect(subject.permission?(:send_messages)).to be true
    end

    it 'unsets a permission' do
      subject.can_send_messages = true
      subject.can_send_messages = false
      expect(subject.permission?(:send_messages)).to be false
    end

    it 'calls write on its writer' do
      writer = double
      expect(writer).to receive(:write).at_least(:once)
      OnyxCord::Permissions.new(0, writer).can_view_channel = true
    end

    it 'multiple consecutive setters only write twice' do
      writer = double
      perms = OnyxCord::Permissions.new(0, writer)
      allow(writer).to receive(:write)
      perms.can_send_messages = true  # write called
      perms.can_attach_files = true   # write called again
      expect(writer).to have_received(:write).at_least(:twice)
    end

    it 'administrator alias works' do
      subject.can_administrate = true
      expect(subject.permission?(:administrator)).to be true
    end
  end

  describe '#assign / #assign!' do
    let(:writer) { double }

    it 'mutates bits without persisting' do
      perms = OnyxCord::Permissions.new(0, writer)
      expect(writer).not_to receive(:write)
      perms.assign(send_messages: true, attach_files: true)
      expect(perms.permission?(:send_messages)).to be true
      expect(perms.permission?(:attach_files)).to be true
    end

    it 'mutates and persists with assign!' do
      perms = OnyxCord::Permissions.new(0, writer)
      expect(writer).to receive(:write)
      perms.assign!(send_messages: true)
      expect(perms.permission?(:send_messages)).to be true
    end

    it 'rejects unknown keys in assign' do
      expect { subject.assign(nonexistent: true) }.to raise_error(ArgumentError, /Unknown/)
    end
  end

  describe '#write_bits' do
    it 'persists without change' do
      writer = double
      perms = OnyxCord::Permissions.new(0, writer)
      expect(writer).to receive(:write).with(0)
      perms.write_bits
    end
  end

  describe '#can_*? predicate' do
    it 'reflects current state' do
      subject.can_send_messages = true
      expect(subject.can_send_messages?).to be true
      subject.can_send_messages = false
      expect(subject.can_send_messages?).to be false
    end
  end

  describe '#init_vars' do
    it 'syncs instance variables from bits' do
      instance = OnyxCord::Permissions.new(0)
      instance.bits = OnyxCord::Permissions::BIT_MAP[:administrator] |
                      OnyxCord::Permissions::BIT_MAP[:manage_guild]
      expect(instance.instance_variable_get(:@administrator)).to be true
      expect(instance.instance_variable_get(:@manage_guild)).to be true
      expect(instance.instance_variable_get(:@send_messages)).to be false
    end
  end
end

class ExampleCalculator
  include OnyxCord::PermissionCalculator
  attr_accessor :server, :roles

  def id
    9999
  end

  def resolve_id
    id
  end

  def owner?
    false
  end

  def communication_disabled?
    false
  end

  def permissions_ivar
    nil
  end
end

describe OnyxCord::PermissionCalculator do
  subject { ExampleCalculator.new }

  def perm_instance(*symbols)
    OnyxCord::Permissions.new(symbols)
  end

  def ow_allow(perms)
    double('allow obj', allow: perms, deny: perm_instance)
  end

  def ow_deny(perms)
    double('deny obj', allow: perm_instance, deny: perms)
  end

  def ow_none
    double('none overwrite', allow: perm_instance, deny: perm_instance)
  end

  # PermissionCalculator algoritm official Discord order tests (UTIL-0001)
  describe '#defined_role_permission?' do
    let(:everyone_role) do
      double('everyone role', id: 0, permissions: perm_instance)
    end

    let(:channel) { double('channel') }

    before do
      subject.server = double('server', everyone_role: everyone_role)
    end

    it '@everyone deny kills base, but role allow revives via allowed overwrite' do
      everyone_role = double('everyone role', id: 0, permissions: perm_instance(:send_messages))
      role_a = double('role a', id: 1, permissions: perm_instance)
      role_b = double('role b', id: 2, permissions: perm_instance(:send_messages))

      everyone_ow = ow_deny(perm_instance(:send_messages))
      role_a_ow = ow_none
      role_b_ow = ow_allow(perm_instance(:send_messages))

      overrides = {
        everyone_role.id => everyone_ow,
        role_a.id => role_a_ow,
        role_b.id => role_b_ow,
      }

      allow(channel).to receive(:permission_overwrites) { overrides }
      subject.server = double('server', everyone_role: everyone_role)
      subject.roles = [role_a, role_b]

      expect(subject.__send__(:defined_role_permission?, :send_messages, channel)).to be true
    end

    it '@everyone allow doesn\'t close calculation before roles' do
      everyone_role = double('everyone role', id: 0, permissions: perm_instance)
      role_a = double('role a', id: 1, permissions: perm_instance)

      everyone_ow = ow_allow(perm_instance(:view_channel))
      role_ow = ow_deny(perm_instance(:view_channel))

      overrides = {
        everyone_role.id => everyone_ow,
        role_a.id => role_ow,
      }

      allow(channel).to receive(:permission_overwrites) { overrides }
      subject.server = double('server', everyone_role: everyone_role)
      subject.roles = [role_a]

      expect(subject.__send__(:defined_role_permission?, :view_channel, channel)).to be false
    end

    it 'combines multiple role denies and allows per official algorithm' do
      everyone_role = double('everyone role', id: 0, permissions: perm_instance(:send_messages))
      role_a = double('role a', id: 1, permissions: perm_instance)
      role_b = double('role b', id: 2, permissions: perm_instance)

      everyone_ow = ow_none
      role_a_ow = ow_deny(perm_instance(:send_messages))
      role_b_ow = ow_allow(perm_instance(:send_messages))

      overrides = {
        everyone_role.id => everyone_ow,
        role_a.id => role_a_ow,
        role_b.id => role_b_ow,
      }

      allow(channel).to receive(:permission_overwrites) { overrides }
      subject.server = double('server', everyone_role: everyone_role)
      subject.roles = [role_b, role_a]  # order shouldn't matter

      expect(subject.__send__(:defined_role_permission?, :send_messages, channel)).to be true
    end

    it 'result does not depend on role order' do
      everyone_role = double('everyone role', id: 0, permissions: perm_instance)
      role_a = double('role a', id: 1, permissions: perm_instance(:send_messages))
      role_b = double('role b', id: 2, permissions: perm_instance)

      overrides = {
        everyone_role.id => ow_none,
        role_a.id => ow_none,
        role_b.id => ow_none,
      }

      allow(channel).to receive(:permission_overwrites) { overrides }
      subject.server = double('server', everyone_role: everyone_role)
      channel_double = channel

      # Order 1
      subject.roles = [role_a, role_b]
      r1 = subject.__send__(:defined_role_permission?, :send_messages, channel_double)

      # Order 2
      subject.roles = [role_b, role_a]
      r2 = subject.__send__(:defined_role_permission?, :send_messages, channel_double)

      expect(r1).to eq r2
      expect(r1).to be true
    end

    it 'member overwrite overrides role result' do
      everyone_role = double('everyone role', id: 0, permissions: perm_instance)
      role_a = double('role a', id: 1, permissions: perm_instance(:send_messages))

      member_ow = ow_deny(perm_instance(:send_messages))

      overrides = {
        everyone_role.id => ow_none,
        role_a.id => ow_none,
        subject.id => member_ow,
      }

      allow(channel).to receive(:permission_overwrites) { overrides }
      subject.server = double('server', everyone_role: everyone_role)
      subject.roles = [role_a]

      expect(subject.permission?(:send_messages, channel_double)).to be false
    end

    let(:channel_double) { channel }

    # UTIL-0006: implicit permissions
    describe 'implicit permissions' do
      let(:everyone_role) do
        double('everyone role', id: 0, permissions: perm_instance(:send_messages, :embed_links, :attach_files))
      end

      before do
        overrides = { everyone_role.id => ow_none }
        allow(channel).to receive(:permission_overwrites) { overrides }
        subject.server = double('server', everyone_role: everyone_role)
        subject.roles = []
      end

      it 'send_messages is implicitly denied when view_channel is denied' do
        everyone_role_b = double('everyone role', id: 0, permissions: perm_instance(:send_messages))
        overrides = { everyone_role_b.id => ow_none }
        allow(channel).to receive(:permission_overwrites) { overrides }
        subject.server = double('server', everyone_role: everyone_role_b)

        expect(subject.permission?(:send_messages)).to be false
      end

      it 'embed_links requires both view_channel and send_messages' do
        restricted = double('everyone role', id: 0,
                            permissions: perm_instance(:view_channel, :send_messages, :embed_links))
        overrides = { restricted.id => ow_none }
        allow(channel).to receive(:permission_overwrites) { overrides }
        subject.server = double('server', everyone_role: restricted)

        expect(subject.permission?(:embed_links)).to be true
      end

      it 'embed_links is implicitly denied when send_messages is denied' do
        restricted = double('everyone role', id: 0,
                            permissions: perm_instance(:view_channel, :embed_links))
        overrides = { restricted.id => ow_none }
        allow(channel).to receive(:permission_overwrites) { overrides }
        subject.server = double('server', everyone_role: restricted)

        # send_messages is NOT in perms
        expect(subject.permission?(:embed_links)).to be false
      end

      it 'attach_files is implicitly denied when send_messages is denied' do
        restricted = double('everyone role', id: 0,
                            permissions: perm_instance(:view_channel, :attach_files))
        overrides = { restricted.id => ow_none }
        allow(channel).to receive(:permission_overwrites) { overrides }
        subject.server = double('server', everyone_role: restricted)

        expect(subject.permission?(:attach_files)).to be false
      end

      it 'speak is implicitly denied when connect is denied' do
        restricted = double('everyone role', id: 0,
                            permissions: perm_instance(:view_channel, :speak))
        overrides = { restricted.id => ow_none }
        allow(channel).to receive(:permission_overwrites) { overrides }
        subject.server = double('server', everyone_role: restricted)

        expect(subject.permission?(:speak)).to be false
      end
    end

    # UTIL-0103: timeout
    describe 'timed out members' do
      let(:everyone_role) do
        double('everyone role', id: 0,
               permissions: perm_instance(:view_channel, :send_messages,
                                         :read_message_history, :attach_files,
                                         :connect, :speak))
      end

      before do
        overrides = { everyone_role.id => ow_none }
        allow(channel).to receive(:permission_overwrites) { overrides }
        subject.server = double('server', everyone_role: everyone_role)
        subject.roles = []
      end

      it 'allows only view_channel and read_message_history when timed out' do
        calculator = ExampleCalculator.new
        calculator.server = double('server', everyone_role: everyone_role)
        calculator.roles = []

        allow(calculator).to receive(:owner?).and_return(false)
        allow(calculator).to receive(:communication_disabled?).and_return(true)
        # administrator check returns false (no admin)
        allow(calculator).to receive(:defined_permission?)
          .with(:administrator, anything, time: anything)
          .and_return(false)

        # timeout only allows view_channel and read_message_history
        expect(calculator.permission?(:view_channel)).to be true
        expect(calculator.permission?(:read_message_history)).to be true
        expect(calculator.permission?(:send_messages)).to be false
        expect(calculator.permission?(:connect)).to be false
      end

      it 'owner bypasses timeout' do
        calculator = ExampleCalculator.new
        calculator.server = double('server', everyone_role: everyone_role)
        calculator.roles = []

        allow(calculator).to receive(:owner?).and_return(true)
        allow(calculator).to receive(:communication_disabled?).and_return(true)

        expect(calculator.permission?(:send_messages)).to be true
        expect(calculator.permission?(:kick_members)).to be true
      end

      it 'administrator bypasses timeout' do
        calculator = ExampleCalculator.new
        calculator.server = double('server', everyone_role: everyone_role)
        calculator.roles = []

        allow(calculator).to receive(:owner?).and_return(false)
        allow(calculator).to receive(:communication_disabled?).and_return(true)
        allow(calculator).to receive(:defined_permission?)
          .with(:administrator, anything, time: anything).and_return(true)

        expect(calculator.permission?(:send_messages)).to be true
      end
    end
  end

  describe '#permission?' do
    it 'owner irrevocably has all permissions' do
      allow(subject).to receive(:owner?).and_return(true)
      expect(subject.permission?(:ban_members)).to be true
    end

    it 'administrator bypasses everything' do
      allow(subject).to receive(:owner?).and_return(false)
      allow(subject).to receive(:defined_permission?).and_call_original
      allow(subject).to receive(:defined_permission?)
        .with(:administrator, anything, time: anything)
        .and_return(true)

      expect(subject.permission?(:ban_members)).to be true
    end

    it 'rejects unknown actions' do
      allow(subject).to receive(:owner?).and_return(false)
      allow(subject).to receive(:defined_permission?).and_call_original
      allow(subject).to receive(:defined_permission?)
        .with(:administrator, anything, time: anything)
        .and_return(false)

      expect { subject.permission?(:foobar) }.to raise_error(ArgumentError, /Unknown/)
    end
  end

  describe '#can_*? predicates' do
    it 'exists for every registered permission' do
      OnyxCord::Permissions::REGISTRY.each_key do |canonical|
        expect(subject.respond_to?(:"can_#{canonical}?")).to be true
      end
    end
  end
end