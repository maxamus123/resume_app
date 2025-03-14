# WickedPDF Global Configuration
#
# Use this to set up shared configuration options for your entire application.
# Any of the configuration options shown here can also be applied to single
# controllers by passing arguments to the `render :pdf` call.
#
# To learn more, check out the README:
#
# https://github.com/mileszs/wicked_pdf/blob/master/README.md

WickedPdf.config = {
  # Path to the wkhtmltopdf executable: This usually isn't needed if using
  # the wkhtmltopdf-binary gem, but if it is needed uncomment the line below
  # :exe_path => '/usr/local/bin/wkhtmltopdf',
  
  # Layout file to be used for all PDFs
  # (but can be overridden in `render :pdf` calls)
  layout: 'pdf.html.erb',
  
  # Customize the rendering options
  orientation: 'Portrait',
  page_size: 'Letter',
  margin: {
    top: 10,
    bottom: 10,
    left: 10,
    right: 10
  }
} 