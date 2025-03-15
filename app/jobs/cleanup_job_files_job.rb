class CleanupJobFilesJob < ApplicationJob
  queue_as :default

  def perform
    # Find all job descriptions older than 24 hours
    cutoff_time = 24.hours.ago
    old_job_descriptions = JobDescription.where('created_at < ?', cutoff_time)
    
    # Log how many files will be cleaned up
    Rails.logger.info "CleanupJobFilesJob: Cleaning up #{old_job_descriptions.count} job descriptions created before #{cutoff_time}"
    
    # Clean up the files and records
    old_job_descriptions.each do |job_description|
      # Delete the attached file if it exists
      if job_description.document.attached?
        Rails.logger.info "CleanupJobFilesJob: Purging document for job description #{job_description.id}"
        job_description.document.purge
      end
      
      # Delete the job description record
      job_description.destroy
      Rails.logger.info "CleanupJobFilesJob: Destroyed job description #{job_description.id}"
    end
    
    # Optionally, clean up any orphaned blobs
    ActiveStorage::Blob.unattached.where('active_storage_blobs.created_at < ?', cutoff_time).each do |blob|
      Rails.logger.info "CleanupJobFilesJob: Purging orphaned blob #{blob.id}"
      blob.purge
    end
  end
end
