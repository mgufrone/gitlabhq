class DashboardController < ApplicationController
  respond_to :html

  before_filter :load_projects, except: [:projects]
  before_filter :event_filter, only: :show

  def show
    # Fetch only 30 projects.
    # If user needs more - point to Dashboard#projects page
    @projects_limit = 30

    @groups = current_user.authorized_groups.sort_by(&:human_name)
    @has_authorized_projects = @projects.count > 0
    @projects_count = @projects.count
    @projects = @projects.limit(@projects_limit)

    @events = Event.in_projects(current_user.authorized_projects.pluck(:id))
    @events = @event_filter.apply_filter(@events)
    @events = @events.limit(20).offset(params[:offset] || 0)

    @last_push = current_user.recent_push

    respond_to do |format|
      format.html
      format.json { pager_json("events/_events", @events.count) }
      format.atom { render layout: false }
    end
  end

  def projects
    @projects = case params[:scope]
                when 'personal' then
                  current_user.namespace.projects
                when 'joined' then
                  current_user.authorized_projects.joined(current_user)
                when 'owned' then
                  current_user.owned_projects
                else
                  current_user.authorized_projects
                end

    @projects = @projects.where(namespace_id: Group.find_by_name(params[:group])) if params[:group].present?
    @projects = @projects.where(visibility_level: params[:visibility_level]) if params[:visibility_level].present?
    @projects = @projects.includes(:namespace).sorted_by_activity

    @labels = current_user.authorized_projects.tags_on(:labels)
    @groups = current_user.authorized_groups

    @projects = @projects.tagged_with(params[:label]) if params[:label].present?
    @projects = @projects.page(params[:page]).per(30)
  end

  def merge_requests
    @merge_requests = FilterContext.new(MergeRequest, current_user, params).execute
    @merge_requests = @merge_requests.recent.page(params[:page]).per(20)
  end

  def issues
    @issues = FilterContext.new(Issue, current_user, params).execute
    @issues = @issues.recent.page(params[:page]).per(20)
    @issues = @issues.includes(:author, :project)

    respond_to do |format|
      format.html
      format.atom { render layout: false }
    end
  end

  protected

  def load_projects
    @projects = current_user.authorized_projects.sorted_by_activity.non_archived
  end
end
