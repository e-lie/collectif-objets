# frozen_string_literal: true

module Synchronizer
  module Edifices
    class Revision
      def initialize(row)
        @row = row
      end

      def synchronize
        return unless row_valid?

        find_edifice
        return unless @edifice

        @edifice.assign_attributes(merimee_REF:, nom:, code_insee:, slug:)
        return unless @edifice.changed?

        Rails.logger.info "edifice #{@identified_by} changed : #{@edifice.changes}, saving..."
        @edifice.save!
      end

      private

      def merimee_REF = @row["reference"]
      def nom = @row["titre_editorial_de_la_notice"]
      def slug = Edifice.slug_for(@row["titre_editorial_de_la_notice"])

      def code_insee
        if @row["cog_insee_lors_de_la_protection"].is_a?(String)
          @row["cog_insee_lors_de_la_protection"].split(",")[0] # when from CSV
        elsif @row["cog_insee_lors_de_la_protection"].is_a?(Array)
          @row["cog_insee_lors_de_la_protection"][0] # when from API
        end
      end

      def row_valid?
        raise "missing merimee_REF in #{row.to_h}" if merimee_REF.blank? # maybe we should just skip

        code_insee.present?
      end

      def find_edifice
        @edifice, @identified_by = find_edifice_by_merimee_REF || find_edifice_by_slug_and_code_insee
      end

      def find_edifice_by_merimee_REF
        edifice = Edifice.find_by(merimee_REF:)
        return unless edifice

        [edifice, { merimee_REF: }]
      end

      def find_edifice_by_slug_and_code_insee
        return if slug.blank? || code_insee.blank?

        edifice = Edifice.find_by(slug:, code_insee:, merimee_REF: nil)
        return unless edifice

        [edifice, { slug:, code_insee: }]
      end
    end
  end
end
