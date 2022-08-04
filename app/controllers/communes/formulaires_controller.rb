# frozen_string_literal: true

module Communes
  class FormulairesController < BaseController
    before_action :enqueue_generate_pdf

    def show; end

    def enqueue_generate_pdf
      if @commune.formulaire.attached? &&
         @commune.formulaire_updated_at &&
         @commune.formulaire_updated_at >= @commune.updated_at
        return true
      end

      @commune.formulaire&.purge
      GenerateFormulaireJob.perform_async(@commune.id)
    end
  end
end
