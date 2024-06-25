# frozen_string_literal: true

module Admin
  class CommunesController < BaseController
    def index
      @ransack = Commune.include_statut_global.ransack(params[:q])
      @query_present = params[:q].present?
      @pagy, @communes = pagy(
        @ransack.result, items: 20
      )
    end

    def show
      @commune = Commune.find(params[:id])
      @messages = Message.where(commune: @commune).order(created_at: :asc)
    end

    private

    def active_nav_links = %w[Communes]
  end
end
