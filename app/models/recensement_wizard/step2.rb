# frozen_string_literal: true

module RecensementWizard
  class Step2 < Base
    STEP_NUMBER = 2
    TITLE = "Précisions sur la localisation"

    validates \
      :edifice_nom,
      presence: {
        message: "Veuillez préciser le nom de l’édifice dans lequel l’objet a été déplacé"
      }, unless: -> { edifice_id.present? }

    def permitted_params = %i[edifice_id edifice_nom]

    def assign_attributes(attributes)
      super

      recensement.edifice_nom = nil if edifice_id.present?
    end
  end
end
