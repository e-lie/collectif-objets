# frozen_string_literal: true

class RelanceDossierIncompletJob < ApplicationJob
  def perform(dossier_id)
    dossier = Dossier.find(dossier_id)
    commune = dossier.commune
    user = commune.users.first
    UserMailer.with(user:, commune:).relance_dossier_incomplet.deliver_later
  end
end
