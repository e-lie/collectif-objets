# frozen_string_literal: true

module Galerie
  class FrameComponent < ViewComponent::Base
    include ApplicationHelper
    include Turbo::FramesHelper

    attr_reader :photos, :title, :turbo_frame, :current_photo_id, :path_without_query, :display_actions

    delegate :count, to: :photos

    def initialize(photos:, title:, turbo_frame:, current_photo_id:, path_without_query:, display_actions: false)
      super
      @title = title
      @turbo_frame = turbo_frame
      @current_photo_id = current_photo_id
      @path_without_query = path_without_query
      @display_actions = display_actions
      @photos = photos
      @photos.each { augment_photo_presenter(_1) }
    end

    def augment_photo_presenter(photo_presenter)
      photo_presenter.lightbox_path_params = { current_photo_id_param_name => photo_presenter.id }
      photo_presenter.lightbox_path = "#{path_without_query}?#{photo_presenter.lightbox_path_params.to_query}"
    end

    def close_path = path_without_query
    def current_photo_id_param_name = "#{turbo_frame}_photo_id"

    def call
      turbo_frame_tag turbo_frame do
        if current_photo_id
          render Galerie::LightboxComponent.new(self)
        else
          render Galerie::MiniaturesComponent.new(self)
        end
      end
    end
  end
end