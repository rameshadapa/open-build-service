class ConfigurationController < ApplicationController

  include ApplicationHelper

  before_filter :require_admin
  before_filter :require_available_architectures, :only => [:index, :update_architectures]

  def index
  end

  def connect_instance
  end

  def users
    @users = []
    Person.find(:all).each do |u|
      person = Person.find(u.value('name'))
      @users << person if person
    end
  end
  
  def groups
    @groups = []
    Group.find(:all).each do |g|
      group = Group.find(g.value('name'))
      @groups << group if group
    end
  end

  def save_instance
    #store project
    required_parameters :name, :title, :description, :remoteurl

    if params[:name].blank? || !valid_project_name?( params[:name] )
      flash[:error] = "Invalid project name '#{params[:name]}'."
      redirect_to :action => :connect_instance and return
    end

    project_name = params[:name].strip

    if Project.exists? project_name
      flash[:error] = "Project '#{project_name}' already exists."
      redirect_to :action => :connect_instance and return
    end

    @project = Project.new(:name => project_name)
    @project.title.text = params[:title]
    @project.description.text = params[:description]
    @project.set_remoteurl(params[:remoteurl])

    if @project.save
      if Project.exists? "home:#{@user.login.to_s}"
        flash[:notice] = "Project '#{project_name}' was created successfully"
        redirect_to :controller => project, :action => 'show', :project => project_name and return
      else
        flash[:notice] = "Project '#{project_name}' was created successfully. Next step is create your home project"
        redirect_to :controller => :project, :action => :new, :ns => "home:#{@user.login.to_s}"
      end
    else
      flash[:error] = "Failed to save project '#{@project}'"
    end
  end

  def update_configuration
    if ! (params[:name]  || params[:title] || params[:description])
      flash[:error] = "Missing arguments (name, title or description)"
      redirect_back_or_to :action => 'index' and return
    end

    begin
      archs=[]
      params[:archs].each do |a|
         archs << a[0] if a[1] == "1"
      end
      ActiveXML::transport.http_json :put, '/configuration', { description: params[:description], title: params[:title], name: params[:name], arch: archs }
      flash[:notice] = "Updated configuration"
      Rails.cache.delete('configuration')
    rescue ActiveXML::Transport::Error 
      logger.debug "Failed to update configuration"
      flash[:error] = "Failed to update configuration"
    end
    redirect_to :action => 'index'
  end

  def update_architectures
    @available_architectures.each do |arch_elem|
      arch = Architecture.find_cached(arch_elem.name) # fetch a real 'Architecture' from 'directory' entry
      if params[:arch_recommended] and params[:arch_recommended].include?(arch.name) and arch.recommended.text == 'false'
        arch.recommended.text = 'true'
        arch.save
        Architecture.free_cache(:available)
      elsif arch.recommended.text == 'true'
        arch.recommended.text = 'false'
        arch.save
        Architecture.free_cache(:available)
      end
    end
    redirect_to :action => 'index'
  end

end
