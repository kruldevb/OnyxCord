# frozen_string_literal: true

require 'onyxcord/utils/message_components'

# A reusable view representing a component collection, with builder methods.
class OnyxCord::Webhooks::View
  # Possible button style names and values.
  BUTTON_STYLES = {
    primary: 1,
    secondary: 2,
    success: 3,
    danger: 4,
    link: 5,
    premium: 6
  }.freeze

  # Possible separator size names and values.
  SEPARATOR_SIZES = {
    small: 1,
    large: 2
  }.freeze

  # Component types.
  # @see https://discord.com/developers/docs/components/reference#component-object-component-types
  COMPONENT_TYPES = {
    action_row: 1,
    button: 2,
    string_select: 3,
    # text_input: 4, # (defined in modal.rb)
    user_select: 5,
    role_select: 6,
    mentionable_select: 7,
    channel_select: 8,
    section: 9,
    text_display: 10,
    thumbnail: 11,
    media_gallery: 12,
    file: 13,
    separator: 14,
    container: 17
    # label: 18, # (defined in modal.rb)
    # file_upload: 19, (defined in modal.rb)
    # radio_group: 21, (defined in modal.rb)
    # checkbox_group: 22, (defined in modal.rb)
    # checkbox: 23 (defined in modal.rb)
  }.freeze

  IS_COMPONENTS_V2 = OnyxCord::MessageComponents::IS_COMPONENTS_V2
  V2_COMPONENT_TYPES = OnyxCord::MessageComponents::V2_COMPONENT_TYPES

  require 'onyxcord/webhooks/view/row_builder'
  require 'onyxcord/webhooks/view/select_menu_builder'
  require 'onyxcord/webhooks/view/text_display_builder'
  require 'onyxcord/webhooks/view/separator_builder'
  require 'onyxcord/webhooks/view/file_builder'
  require 'onyxcord/webhooks/view/media_gallery_builder'
  require 'onyxcord/webhooks/view/section_builder'
  require 'onyxcord/webhooks/view/container_builder'

  def initialize
    @components = []

    yield self if block_given?
  end

  # @!visibility private
  def to_a
    @components.map(&:to_h)
  end

  def empty?
    @components.empty?
  end

  def any?
    @components.any?
  end

  def components_v2?
    self.class.components_v2?(to_a)
  end

  alias v2? components_v2?

  def flags(flags = 0)
    self.class.apply_v2_flag(flags, to_a)
  end

  def self.components_v2?(components)
    OnyxCord::MessageComponents.components_v2?(components)
  end

  def self.component_payload(components)
    OnyxCord::MessageComponents.payload(components)
  end

  def self.apply_v2_flag(flags, components, force: false)
    OnyxCord::MessageComponents.apply_v2_flag(flags, components, force: force)
  end

  # Add a row component to the view.
  # @see RowBuilder#initialize
  def row(id: nil)
    builder = RowBuilder.new(id: id)
    @components << builder
    yield builder if block_given?
    builder
  end

  # Add a file component to the view.
  # @see FileBuilder#initialize
  def file(...)
    builder = FileBuilder.new(...)
    @components << builder
    builder
  end

  alias_method :file_display, :file

  # Add a section component to the view.
  # @see SectionBuilder#initialize
  def section(id: nil)
    builder = SectionBuilder.new(id: id)
    @components << builder
    yield builder if block_given?
    builder
  end

  # Add a separator component to the view.
  # @see SeparatorBuilder#initialize
  def separator(...)
    builder = SeparatorBuilder.new(...)
    @components << builder
    builder
  end

  # Add a container component to the view.
  # @see ContainerBuilder#initialize
  def container(id: nil, color: nil, colour: nil, spoiler: false)
    builder = ContainerBuilder.new(id: id, color: color, colour: colour, spoiler: spoiler)
    @components << builder
    yield builder if block_given?
    builder
  end

  # Add a text display component to the view.
  # @see TextDisplayBuilder#initialize
  def text_display(...)
    builder = TextDisplayBuilder.new(...)
    @components << builder
    builder
  end

  # Add a media gallery component to the view.
  # @see MediaGalleryBuilder#initialize
  def media_gallery(*items, id: nil)
    builder = MediaGalleryBuilder.new(*items, id: id)
    @components << builder
    yield builder if block_given?
    builder
  end
end
