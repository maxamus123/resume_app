# Only schedule jobs in production environment
if Rails.env.production?
  require 'rufus-scheduler'

  # Let's create a scheduler
  scheduler = Rufus::Scheduler.singleton

  # Schedule the cleanup job to run every day at 3 AM
  scheduler.cron '0 3 * * *' do
    Rails.logger.info "Running scheduled CleanupJobFilesJob at #{Time.now}"
    CleanupJobFilesJob.perform_later
  end
end

# Note: For development/testing, you would run the job manually:
# CleanupJobFilesJob.perform_later 