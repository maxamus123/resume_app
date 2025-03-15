class JobDescriptionsController < ApplicationController
  def upload
    @job_description = JobDescription.new
  end

  def analyze
    @job_description = JobDescription.new(job_description_params)
    
    if @job_description.save
      # Extract text from document if provided
      extracted_text = ""
      if @job_description.document.attached?
        # We'll use the OpenAI API to process the document directly
        # So we don't need to extract text separately
        extracted_text = "Document uploaded successfully."
      else
        # If no document is provided, use the provided text
        extracted_text = @job_description.title # This is simplistic, you might want more fields
      end
      
      # Analyze the job description
      openai_service = OpenaiService.new
      @analysis = openai_service.analyze_job_fit(@job_description)
      
      # Store the analysis in the database
      @job_description.update(analysis: @analysis)
      
      # Respond appropriately based on the request format
      respond_to do |format|
        format.html { render :analyze }
        format.turbo_stream # Will automatically render analyze.turbo_stream.erb
      end
    else
      # If there were errors, re-render the upload form
      respond_to do |format|
        format.html { render :upload }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("main-content", template: "job_descriptions/upload") }
      end
    end
  end
  
  private
  
  def job_description_params
    params.require(:job_description).permit(:title, :company, :document, :session_id)
  end
end
