# frozen_string_literal: true

module Admin
  class DossiersController < BaseController
    def show
      @dossier = Dossier.find(params[:id])
      @commune = @dossier.commune # Requis par shared/dossier_rapport
    end

    def update
      @dossier = Dossier.find(params[:id])
      raise if params[:status] != "construction"

      @dossier.return_to_construction!
      redirect_to admin_commune_path(@dossier.commune),
                  notice: "Commune repassée en recensement & dossier repassé en construction"
    end

    private

    def active_nav_links = %w[Communes]
  end
end
