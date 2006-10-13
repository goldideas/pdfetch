require 'camping'
require 'bio'
require 'mechanize'

Camping.goes :Pdfetch

module Pdfetch::Controllers

  class MainCss < R '/main.css'
    def get
      @headers["Content-Type"] = "text/css; charset=utf-8"
      @body = %{

/* main.css */
body { margin: 0; padding: 10; font-size: medium; font-family: arial, sans; }
a { text-decoration: none;}
h1 { font-size: 110%; }
p { font-size: 90%; }

}
    end
  end

  class Static < R '/(\d+)\.pdf$'         
    def get(id)
      @pmid = id
      @headers['Content-Type'] = "application/pdf"
      @headers['X-Sendfile'] = "#{Dir.getwd}/#{id}.pdf"
    end
  end 
  
  class Index < R '/(\d+)$'
    def get(id)
      @pmid = id
      begin
        unless File.exist?("#{id}.pdf")
          # fetch the article from pubmed using pmid
          @article = Bio::MEDLINE.new(Bio::PubMed.query(id))
          m = WWW::Mechanize.new
          p = m.get("http://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi?dbfrom=pubmed&id=#{id}&retmode=ref&cmd=prlinks")
          if @article.journal.strip =~ /^nature/i
            p = m.click p.links.with.text(/full/i).and.href(/full/i)
            p = m.click p.links.with.href(/.pdf$/i)
            p.save_as("#{id}.pdf")
          elsif frame = p.frames.with.name(/reprint/i) and not frame.empty?
            p = m.click frame
            p = m.click p.links.with.href(/.pdf$/i)
            p.save_as("#{id}.pdf")
          elsif link = p.links.with.text(/pdf/i).and.href(/.pdf$/i) and not link.empty?
            p = m.click link
            p.save_as("#{id}.pdf")
          else
            p = m.click p.links.with.text(/pdf/i).and.href(/reprint/i)
            p = m.click p.frames.with.name(/reprint/i)
            p = m.click p.links.with.href(/.pdf$/i)
            p.save_as("#{id}.pdf")
          end
        end
        render :index
      rescue
        render :error
      end
    end    
  end
end

module Pdfetch::Views

  def layout
    xhtml_strict do
      head do
        link :rel => 'stylesheet', :type => 'text/css', :href => '/main.css', :media => 'screen'
        script "function goback(){window.history.back()}function waitngoback(){window.setTimeout(goback(),3000);}", :type => 'text/javascript'
      end
#      body :onload => 'waitngoback()' do
      body do
        self << yield
        p { "Click #{a 'here', :href => '#', :onclick => 'goback()'} to go back, or click #{a "here", :href => "#{@pmid}.pdf"} to view the reprint." }
      end
    end
  end

  def index
    p "PDFetch successfully fetched reprint from publisher."
  end

  def error
    p "PDFetch cannot fetch article from PubMed or reprint from publisher. Check that the browser url is correct and that the internet connection is working."
  end

end