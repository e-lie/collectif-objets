# frozen_string_literal: true

class Objet < ApplicationRecord
  include ActionView::Helpers::TextHelper # for truncate

  scope :with_images, -> { where("cardinality(palissy_photos) >= 1") }
  belongs_to :commune, foreign_key: :lieu_actuel_code_insee, primary_key: :code_insee, optional: true,
                       inverse_of: :objets, counter_cache: true
  belongs_to :edifice, optional: true
  has_one :departement, through: :commune
  has_one :nouveau_departement, class_name: "Departement", primary_key: :lieu_actuel_departement_code,
                                foreign_key: :code
  has_one :nouvelle_commune, class_name: "Commune", primary_key: :lieu_actuel_code_insee, foreign_key: :code_insee
  has_one :nouvel_edifice, class_name: "Edifice", primary_key: :lieu_actuel_edifice_ref, foreign_key: :merimee_REF
  has_many :recensements, dependent: :restrict_with_exception

  has_one :recensement, -> {
    left_outer_joins(objet: { commune: :dossier })
    .where("recensements.dossier_id = dossiers.id")
  }, dependent: :nullify, inverse_of: :objet

  accepts_nested_attributes_for :edifice

  scope :order_by_recensement_priorite, lambda {
    left_outer_joins(commune: :dossier)
    .joins("LEFT JOIN recensements ON recensements.objet_id = objets.id AND recensements.deleted_at IS NULL \
              AND recensements.dossier_id = dossiers.id")
    .order(Arel.sql(Recensement::SQL_ORDER_PRIORITE))
    .order("recensements.analysed_at DESC")
  }

  scope :without_completed_recensements, lambda {
    joins(commune: :dossier)
    .joins("LEFT JOIN recensements ON recensements.objet_id = objets.id AND recensements.dossier_id = dossiers.id \
            AND recensements.deleted_at IS NULL AND recensements.status = 'completed'")
    .where(recensements: { id: nil })
  }

  scope :a_examiner, lambda {
                       joins(:recensements)
                       .where(recensements: { analysed_at: nil })
                       .where(Recensement::RECENSEMENT_PRIORITAIRE_SQL)
                     }
  scope :examinés, lambda {
                     joins(:recensements)
                     .where.not(recensements: { analysed_at: nil })
                   }

  MIS_DE_COTE_SQL = %("palissy_PROT" LIKE 'déclassé au titre objet'
                      OR "palissy_PROT" LIKE 'désinscrit'
                      OR "palissy_PROT" LIKE '%non protégé%'
                      OR "palissy_PROT" LIKE 'sans protection'
                    )
  scope :classés, -> { where(%("palissy_PROT" ILIKE '%classé%')).where.not(MIS_DE_COTE_SQL) }
  scope :inscrits, lambda {
                     where(%("palissy_PROT" ILIKE '%inscr%'))
                     .where.not(%("palissy_PROT" ILIKE '%classé%'))
                     .where.not(MIS_DE_COTE_SQL)
                   }
  scope :protégés, -> { classés.or(inscrits) }
  scope :code_insee_a_changé, -> { where.not(palissy_WEB: nil).where.not(palissy_DEPL: nil) }
  scope :déplacés, -> { joins(:recensement).merge(Recensement.déplacés) }
  scope :manquants, -> { joins(:recensement).merge(Recensement.absent) }

  # old column names still used in code for reads
  alias_attribute :nom, :palissy_TICO
  alias_attribute :categorie, :palissy_CATE
  alias_attribute :commune_nom, :palissy_COM
  alias_attribute :commune_code_insee, :lieu_actuel_code_insee
  # alias_attribute :departement, :palissy_DPT
  alias_attribute :crafted_at, :palissy_SCLE
  alias_attribute :last_recolement_at, :palissy_DENQ
  alias_attribute :nom_dossier, :palissy_DOSS
  alias_attribute :edifice_nom, :palissy_EDIF
  alias_attribute :emplacement, :palissy_EMPL

  def edifice_nom_formatted
    if edifice_nom == "église" && commune.present?
      "Une église de #{commune.nom}"
    else
      edifice_nom&.capitalize
    end
  end

  def nom_with_ref_pop
    truncate("#{palissy_REF} #{nom}", length: 40)
  end

  def recensement? = recensement.present?

  def recensement_completed?
    !recensement.nil? && recensement.completed?
  end

  def self.select_best_objet_in_list(objets_arr)
    current_arr = objets_arr
    [
      ->(obj) { obj.palissy_photos.any? },
      ->(obj) { obj.nom.exclude?(";") },
      ->(obj) { obj.nom.match?(/[A-Z]/) },
      ->(obj) { obj.edifice_nom.present? },
      ->(obj) { obj.edifice_nom&.match?(/[A-Z]/) },
      ->(obj) { obj.emplacement.blank? }
    ].each do |filter_fun|
      filtered_arr = current_arr.filter { filter_fun.call(_1) }
      current_arr = filtered_arr if filtered_arr.any?
    end
    current_arr.first
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def palissy_photos_presenters
    palissy_photos.each_with_index.map { |photo, index| PhotoPresenter.from_palissy_photo(photo, index) }
  end

  def to_s = palissy_TICO
  def nom = (super || [palissy_DENO || categorie || palissy_REF, crafted_at].compact_blank.join(", ")).upcase_first
  def déplacé? = palissy_WEB.present? && palissy_DEPL.present?
  def code_insee_a_changé? = palissy_WEB.present? && palissy_DEPL.blank?

  def nouvel_edifice
    super&.nom || lieu_actuel_edifice_nom unless déplacé?
  end

  def destroy_and_soft_delete_recensement!(**kwargs)
    transaction do
      recensements.each { _1.destroy_or_soft_delete!(**kwargs) }
      recensements.reload # necessary here, objet.recensements must be empty before destroy
      destroy!
    end
  end

  def snapshot_attributes
    attributes.slice("palissy_REF", "palissy_TICO", "lieu_actuel_code_insee", "lieu_actuel_edifice_nom")
  end
end
