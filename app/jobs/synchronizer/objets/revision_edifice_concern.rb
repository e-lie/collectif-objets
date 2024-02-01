# frozen_string_literal: true

module Synchronizer
  module Objets
    module RevisionEdificeConcern
      extend ActiveSupport::Concern

      def new_edifice?
        edifice_attributes.key?(:edifice_attributes)
      end

      private

      def edifice_attributes
        @edifice_attributes ||= compute_edifice_attributes
      end

      def compute_edifice_attributes
        palissy_INSEE = @objet_attributes[:palissy_INSEE]
        if palissy_INSEE.blank?
          {}
        elsif existing_edifice_by_ref && existing_edifice_by_ref.code_insee == palissy_INSEE
          { edifice_id: existing_edifice_by_ref.id }
        elsif existing_edifice_by_code_insee_and_slug
          { edifice_id: existing_edifice_by_code_insee_and_slug.id }
        elsif existing_edifice_by_ref && existing_edifice_by_ref.code_insee != palissy_INSEE
          # l’édifice trouvé via le REFA est dans une autre commune, on ne l’utilise pas pour cet
          # objet et on en créé un nouveau dans la bonne commune sans REFA pour éviter un conflit
          { edifice_attributes: new_edifice_attributes.except(:merimee_REF) }
        else
          { edifice_attributes: new_edifice_attributes }
        end
      end

      def existing_edifice_by_ref = @eager_loaded_records.edifice_by_ref
      def existing_edifice_by_code_insee_and_slug = @eager_loaded_records.edifice_by_code_insee_and_slug

      def new_edifice_attributes
        {
          merimee_REF: @objet_attributes[:palissy_REFA].presence,
          code_insee: @objet_attributes[:palissy_INSEE],
          slug: ::Edifice.slug_for(@objet_attributes[:palissy_EDIF]),
          nom: @objet_attributes[:palissy_EDIF]
        }
      end
    end
  end
end
