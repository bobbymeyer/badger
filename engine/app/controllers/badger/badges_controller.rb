module Badger
  class BadgesController < ApplicationController
    # Twelve is three rows of cards at the page's width. A layout decision,
    # so it lives beside the layout and not in the model.
    PER_PAGE = 12

    before_action :set_badge, only: %i[ show edit update destroy ]

    # Narrowed by a name as typed and by whether the badge has been dressed,
    # in one of two orders; the filters are the library's registers and the
    # scopes are the badge's.
    def index
      @sort = Badge::SORTS.key?(params[:sort]) ? params[:sort] : "name"
      @wearing = Badge::WEARING.key?(params[:wearing]) ? params[:wearing] : nil
      @total = Badge.count

      narrowed = Badge.name_matching(params[:q]).wearing(@wearing)
      @pages = [ (narrowed.count / PER_PAGE.to_f).ceil, 1 ].max
      @page = params[:page].to_i.clamp(1, @pages)
      @badges = narrowed.sorted(@sort).offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
    end

    # The page's three surfaces: what the badge is made of, what it wears,
    # how it leaves.
    SECTIONS = %w[ compose dress export ].freeze

    def show
      @section = SECTIONS.include?(params[:section]) ? params[:section] : "compose"
      @colorway = @badge.colorways.find_by(id: params[:colorway]) if params[:colorway]
    end

    def new
      @badge = Badge.new(spec: Seeds.starter(font: Fonts.names.first))
    end

    def edit
    end

    def create
      @badge = Badge.new(badge_params)

      if @badge.save
        redirect_to @badge, notice: "#{@badge.name} composed."
      else
        render :new, status: :unprocessable_content
      end
    end

    # Saved from the edit page as a form, or from the editor as JSON: the
    # editor sends the document it holds and hears back whether it was taken.
    def update
      if @badge.update(badge_params)
        respond_to do |format|
          format.html { redirect_to @badge, notice: "#{@badge.name} saved." }
          format.json { render json: { saved_at: @badge.updated_at.iso8601 } }
        end
      else
        respond_to do |format|
          format.html { render :edit, status: :unprocessable_content }
          format.json { render json: { error: @badge.errors.full_messages.to_sentence }, status: :unprocessable_content }
        end
      end
    end

    def destroy
      @badge.destroy!

      redirect_to badges_path, notice: "#{@badge.name} taken away."
    end

    private
      def set_badge
        @badge = Badge.find(params[:id])
      end

      # The editor sends the document whole, as JSON under `spec`; the edit
      # page sends it as YAML.
      def badge_params
        taken = params.require(:badge)
        return taken.permit(:name, :spec_yaml) unless taken.key?(:spec)

        { name: taken[:name], spec: taken[:spec].respond_to?(:permit!) ? taken[:spec].permit!.to_h : JSON.parse(taken[:spec].to_s) }.compact
      end
  end
end
