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

    def show
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

    def update
      if @badge.update(badge_params)
        redirect_to @badge, notice: "#{@badge.name} saved."
      else
        render :edit, status: :unprocessable_content
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

      def badge_params
        params.expect(badge: [ :name, :spec_yaml ])
      end
  end
end
