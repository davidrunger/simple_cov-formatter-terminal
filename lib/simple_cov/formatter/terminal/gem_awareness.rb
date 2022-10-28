# frozen_string_literal: true

require_relative './spec_to_app_maps'

module GemAwareness
  include SpecToAppMaps

  def gem?
    Dir['*'].any? { _1.end_with?('.gemspec') }
  end

  def default_map
    # dup the maps because the maps are frozen but we want to allow the user to customize them
    gem? ? SPEC_TO_GEM_DEFAULT_MAP.dup : SPEC_TO_APP_DEFAULT_MAP.dup
  end
end
