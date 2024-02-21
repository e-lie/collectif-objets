# frozen_string_literal: true

module Synchronizer
  module Objets
    module Revision
      module UpdateConcern
        extend ActiveSupport::Concern

        def objet
          @objet ||= begin
            persisted_objet.assign_attributes(all_attributes.except(*except_fields))
            persisted_objet
          end
        end

        def synchronize
          return false if row.out_of_scope? || !objet_valid?

          log log_message, counter: action
          objet.save! if action != :not_changed
          true
        end

        private

        def action
          @action ||=
            if apply_commune_change?
              :update_with_commune_change
            elsif ignore_commune_change?
              :update_ignoring_commune_change
            elsif objet.changed?
              :update
            else
              :not_changed
            end
        end

        def objet_valid?
          return true if objet.valid?

          log "mise à jour de l'objet #{palissy_REF} rejeté car l’objet n'est pas valide " \
              ": #{objet.errors.full_messages.to_sentence} - #{all_attributes}",
              counter: :update_rejected_invalid
          false
        end

        def except_fields
          f = %i[palissy_REF]
          if ignore_commune_change?
            f += %i[
              palissy_COM
              palissy_INSEE
              palissy_DPT
              palissy_EDIF
              palissy_EMPL
              palissy_DEPL
              palissy_WEB
              palissy_MOSA
              lieu_actuel_code_insee
              lieu_actuel_edifice_nom
              lieu_actuel_edifice_ref
            ]
          end
          f
        end

        def existing_recensement?
          @existing_recensement ||= persisted_objet.recensements.any?
        end

        def commune_after_update = @eager_loaded_records.commune
        def commune_changed? = commune_before_update != commune_after_update
        def apply_commune_change? = commune_changed? && !existing_recensement?
        def ignore_commune_change? = commune_changed? && !apply_commune_change?

        def log_message
          @log_message ||= begin
            m = "mise à jour de l’objet #{palissy_REF} : #{persisted_objet.changes}"
            case action
            when :update
              m
            when :update_with_commune_change
              "#{m} - changement de commune appliqué #{commune_before_update} → #{commune_after_update || 'ø'} "
            when :update_ignoring_commune_change
              "#{m} - changement de commune ignoré #{commune_before_update} → #{commune_after_update || 'ø'} " \
              "car l’objet a déjà un recensement"
            end
          end
        end
      end
    end
  end
end
