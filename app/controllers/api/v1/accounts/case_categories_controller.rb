class Api::V1::Accounts::CaseCategoriesController < Api::V1::Accounts::BaseController
  before_action :fetch_case_category, only: [:update, :destroy]
  before_action :check_authorization

  def index
    @case_categories = case_categories.order(:c1, :c2, :c3)
    @case_categories = @case_categories.search(params[:q]) if params[:q].present?
    @case_categories = @case_categories.where(inquiry_type: params[:inquiry_type]) if params[:inquiry_type].present?
  end

  def create
    @case_category = case_categories.create!(case_category_params)
  end

  def update
    @case_category.update!(case_category_params)
  end

  def destroy
    @case_category.destroy!
    head :ok
  end

  def template
    send_data CaseCategories::CsvService.template, filename: 'case-categories-template.csv', type: 'text/csv; charset=utf-8'
  end

  def export
    send_data CaseCategories::CsvService.export(case_categories.order(:c1, :c2, :c3)),
              filename: 'case-categories.csv', type: 'text/csv; charset=utf-8'
  end

  def import
    file = params[:file]
    return render_could_not_create_error(I18n.t('errors.case_categories.file_required')) unless file.respond_to?(:read)

    @result = CaseCategories::ImportService.new(account: Current.account, content: file.read).perform
  rescue CSV::MalformedCSVError, EncodingError => e
    render_could_not_create_error(I18n.t('errors.case_categories.unreadable_csv', error: e.message))
  end

  private

  def case_categories
    CaseCategory.where(account_id: Current.account.id)
  end

  def fetch_case_category
    @case_category = case_categories.find(params[:id])
  end

  def check_authorization
    authorize(@case_category || CaseCategory)
  end

  def case_category_params
    params.require(:case_category).permit(:inquiry_type, :c1, :c2, :c3, :sla_respond_minutes, :sla_resolve_minutes)
  end
end
