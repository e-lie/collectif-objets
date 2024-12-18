# frozen_string_literal: true

module Bordereau
  class RecensementRow
    def initialize(recensement)
      @recensement = recensement
    end

    def to_a
      [
        palissy_REF,
        denomination_cell,
        palissy_DPRO, # date de protection
        etat_sanitaire_cell,
        observations,
        photo_cell
      ]
    end

    private

    attr_reader :recensement

    delegate :objet, :absent?, :deplacement_definitif?, :recensable?, :analyse_etat_sanitaire, :etat_sanitaire,
             :localisation, :mauvaise_securisation?, to: :recensement
    delegate :palissy_REF, :palissy_DENO, :palissy_SCLE, :palissy_CATE, :palissy_DPRO, :nom, to: :objet

    def denomination_cell
      materiaux = palissy_CATE ? palissy_CATE.split(";").compact_blank.join(", ").upcase_first : ""
      [nom, palissy_SCLE, materiaux].compact_blank.join("\n")
    end

    def etat_sanitaire_cell
      if absent?
        "Objet introuvable"
      elsif !recensable?
        "Objet non recensable"
      elsif analyse_etat_sanitaire.present?
        analyse_etat_sanitaire
      else
        etat_sanitaire
      end
    end

    def observations
      [
        "<b>Propriétaire :</b>  #{observations_proprietaire_cell.presence || 'Néant'}",
        "<b>Conservateur :</b>  #{recensement.analyse_notes.presence || 'Néant'}"
      ].join("\n")
    end

    def observations_proprietaire_cell
      observations = [recensement.notes]
      observations << ["L’objet a été déplacé vers : #{recensement.edifice_nom}"] if deplacement_definitif?
      observations.compact_blank.join("\n")
    end

    def observations_conservateur_cell
      observations = [recensement.analyse_notes]
      observations << ["L’objet peut être volé facilement"] if mauvaise_securisation?
      observations.compact_blank.join("\n")
    end

    def photo_cell
      return unless recensement.photos.attached?

      image = StringIO.new(recensement.photos.first.variant(:small).processed.download)
      { image:, fit: [65, 65] }
    end
  end
end
