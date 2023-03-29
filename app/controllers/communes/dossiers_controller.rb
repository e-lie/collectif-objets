# frozen_string_literal: true

module Communes
  class DossiersController < BaseController
    before_action :authorize_dossier

    def show
      return unless params[:view] == "print"

      render :show_print, layout: "application_print"
    end

    protected

    def authorize_dossier
      if @dossier
        authorize(@dossier)
      else
        skip_authorization
      end
    end

    def active_nav_links = ["Rapport du conservateur"]
  end
end
