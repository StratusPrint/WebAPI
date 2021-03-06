module Api::V1
  class JobsController < ApiController
    ###########################################################################
    # AUTHORIZATION
    ###########################################################################
    load_and_authorize_resource :printer
    load_and_authorize_resource :job, :through => :printer

    ###########################################################################
    # SWAGGER API DOCUMENTATION
    ###########################################################################
    swagger_path '/jobs/{id}' do
      operation :get do
        key :summary, 'Find a print job by ID '
        key :description, 'Fetches a single print job. Note that user must have access to the parent printer to carry out this action.'
        key :operationId, 'findJobById'
        key :produces, [
          'application/json'
        ]
        key :tags, [
          'Job Management'
        ]
        parameter do
          key :name, :id
          key :in, :path
          key :description, 'ID of the job'
          key :required, :true
          key :type, :integer
        end
        response 200 do
          key :description, 'job response'
          schema do
            key :'$ref', :Job
          end
        end
        response 401 do
          key :description, 'Authorization error'
        end
        response 403 do
          key :description, 'No permission to access'
        end
        response 404 do
          key :description, 'Job not found'
        end
      end
      operation :patch do
        key :summary, 'Update print job by ID'
        key :description, 'Update the specified job if user has access.'
        key :operationId, 'updateJob'
        key :tags, [
          'Job Management'
        ]
        parameter do
          key :name, :id
          key :in, :path
          key :description, 'ID of the job'
          key :required, :true
          key :type, :integer
        end
        parameter do
          key :name, :job
          key :in, :body
          key :description, 'Job object'
          key :required, true
          schema do
            key :'$ref', :Job
          end
        end
        response 200 do
          key :description, 'Job successfully updated'
          schema do
            key :'$ref', :Job
          end
        end
        response 401 do
          key :description, 'Authorization error'
        end
        response 403 do
          key :description, 'No permission to access'
        end
        response 404 do
          key :description, 'Job not found'
        end
        response 422 do
          key :description, 'Validation error(s) - see response for details'
        end
      end
      operation :delete do
        key :summary, 'Cancel an existing job'
        key :description, 'Cancels an existing job. Requires admin priveleges.'
        key :operationId, 'cancelJob'
        key :tags, [
          'Job Management'
        ]
        parameter do
          key :name, :id
          key :in, :path
          key :description, 'ID of the job'
          key :required, :true
          key :type, :integer
        end
        response 204 do
          key :description, 'Job successfully deleted'
        end
        response 401 do
          key :description, 'Authorization error'
        end
        response 403 do
          key :description, 'No permission to access'
        end
        response 404 do
          key :description, 'Job not found'
        end
      end
    end

    ###########################################################################
    # CONTROLLER ACTIONS
    ###########################################################################
    before_action :set_job, only: [:show, :update, :destroy]

    # GET /printers/1/jobs
    def index
      @jobs = Printer.find_by(id: params[:printer_id]).jobs

      render json: @jobs.sort_by(&:created_at).reverse
    end

    # GET /jobs/1
    def show
      render json: @job
    end

    # POST /printers/1/jobs
    def create
      @job = Job.new(job_params.merge(:created_by_user_id => current_user.id))

      if @job.save
        CreateAlertJob.perform_later(@job, 'processing', 'created')
        Printer.find_by(id: params[:printer_id]).jobs << @job
        render json: @job, status: :created, location: v1_job_path(@job)
      else
        render json: @job.errors, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /jobs/1
    def update
      old_status = @job.data['status']
      new_status = job_params[:data][:status]

      if @job.update(job_params)
        if old_status != new_status
          CreateAlertJob.perform_later(@job, new_status, old_status)
        end
        render json: @job
      else
        render json: @job.errors, status: :unprocessable_entity
      end
    end

    # DELETE /jobs/1
    def destroy
      #@job.destroy
      CancelJob.perform_later(@job)
      render json: Messages::CommandIssuedMessage, status: :no_content
    end

    private
    # Use callbacks to share common setup or constraints between actions.
    def set_job
      @job = Job.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def job_params
      params.fetch(:job, {}).permit(:model, :model_file_name, :data => [{:file => [:date, :name, :size, :origin]}, :status, {:filament => [:length, :volume]}, {:progress => [:file_position, :print_time, :completion, :print_time_left]}, :estimated_print_time])
    end
  end
end
