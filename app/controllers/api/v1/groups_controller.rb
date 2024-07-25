class ::Api::V1::GroupsController < ::Api::V1::BaseController
  def index
    groups = Group.order(:id).page(params[:page]).per(params[:per_page])
    render json: groups, status: :ok
  end

  def create
    if current_user.admin?
      @group = Group.new(group_params)
      if @group.save
        render json: {
          id: @group.id,
          name: @group.name,
        }, status: :ok
      else
        is_taken = @group.errors.details[:name].select { |x| x[:error] == :taken }

        if !is_taken.blank?
          existing_group = Group.find_by(name: @group.name)
          render json: {
            status: 'group already exist',
            id: existing_group.id,
            name: existing_group.name,
          }, status: :unprocessable_entity
        else
          render json: {
            status: 'error',
          }, status: :unprocessable_entity
        end
      end
    end
  end

  def add_user
    @group = Group.find_by(id: params[:id])
    return head :not_found unless @group.present?

    return raise_unauthorized unless current_user.admin? || @group.admin?(current_user)

    user = User.find_by(id: params[:user_id])
    return head :unprocessable_entity unless user.present?

    expiration_date = params[:expiration_date]
    @group.add_user_with_expiration(params[:user_id], expiration_date)
    head :no_content
  end

  def list_admins
    group = Group.find(params[:id])
    return head :not_found unless group.present?

    users = group.group_admins.joins(:user).
      select('users.id, users.email, users.name, users.active, group_admins.created_at as join_date').
      where('users.active = ?', true)
    render json: users, status: :ok
  end

  def associated_vpns
    group = Group.find_by_id(params[:id])
    return head :not_found unless group.present?

    vpns = group.vpns
    render json: vpns, status: :ok
  end

  private

  def group_params
    params.require(:group).permit(:name)
  end
end
