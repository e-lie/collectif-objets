# frozen_string_literal: true

module Synchronizer
  module Objets
    class RevisionUpdate
      include RevisionConcern

      def initialize(row, commune: nil, persisted_objet: nil, interactive: false, logfile: nil, dry_run: false)
        @row = row
        @commune = commune
        @persisted_objet = persisted_objet
        @interactive = interactive
        @logfile = logfile
        @dry_run = dry_run
        @commune_before_update = persisted_objet.commune
      end

      def synchronize
        return false unless check_changed

        persisted_objet.assign_attributes attributes_to_assign

        return false unless check_objet_valid

        set_update_action_and_log
        unless dry_run?
          destroy_recensements
          persisted_objet.save!
        end
        true
      end

      def objet = persisted_objet

      private

      attr_reader :persisted_objet, :commune_before_update
      alias commune_after_update commune

      def attributes_to_assign
        except_fields = ["REF"]
        except_fields += %w[COM INSEE DPT EDIF EMPL] if ignore_commune_change?
        objet_builder.attributes.except(*except_fields.map { "palissy_#{_1}" })
      end

      def check_changed
        return true if changed?

        @action = :not_changed
        false
      end

      def check_objet_valid
        return true if persisted_objet.valid?

        @action = :update_rejected_invalid
        log "mise à jour de l'objet #{palissy_ref} rejetée car l’objet n'est pas valide " \
            ": #{persisted_objet.errors.full_messages.to_sentence}"
        false
      end

      def objet_builder
        @objet_builder ||= Synchronizer::Objets::Builder.new(row, persisted_objet:)
      end

      def commune_changed? = commune_before_update != commune_after_update

      def set_update_action_and_log
        message = "mise à jour de l’objet #{palissy_ref}"
        if commune_changed? && persisted_objet.recensements.empty?
          message += " avec changement de commune appliqué #{commune_before_update} → #{commune_after_update}" \
                     "et #{persisted_objet.recensements.count} recensements supprimés"
          @action = :update_with_commune_change_and_recensements_destroyed
        elsif commune_changed?
          message += " avec changement de commune appliqué #{commune_before_update} → #{commune_after_update} "
          @action = :update_with_commune_change
        else
          @action = :update
        end
        message += " : #{persisted_objet.changes}"
        log message
      end

      def destroy_recensements
        nil if !commune_changed? || persisted_objet.recensements.empty?

        persisted_objet.recensements.each(&:destroy!)
      end
    end
  end
end
