# City Of Wanneroo - Planning Proposals Scraper

* Cookie tracking - No
* Pagnation - yes, via a flag in json data
* Javascript - No
* Clearly defined data within a row - No, data is in a json record, but council reference is inconsistent, sometimes you
  have to look in various places on detail page
* System - socialpinpoint and Hive (v5?) - https://docs.strangebee.com/

This is a scraper that runs on [Morph](https://morph.io). 
To get started [see the documentation](https://morph.io/documentation)

Add any issues to https://github.com/planningalerts-scrapers/issues/issues

## To run the scraper

    bundle exec ruby scraper.rb

### Expected output

    Getting planning-proposals page
      Pausing 3.16s
    Getting page: 0: https://yoursay.wanneroo.wa.gov.au/ccm/the_hive_projects/tools/the_hive_projects_list/load_more/2693?page=0
    /home/ianh/.local/share/mise/installs/ruby/3.2.2/lib/ruby/gems/3.2.0/gems/mechanize-2.8.5/lib/mechanize/pluggable_parsers.rb:107:in `new': MIME::Type.MIME::Type.new when called with a String is deprecated.
    Saving record DA2025/1791 - 33 Ocean Falls Boulevard, Mindarie, WA
    Saving record DA2025/1622 - 102 Glasshouse Drive, Banksia Grove, WA
    Saving record DA2025/1795 - 111 Girrawheen Avenue, Girrawheen, WA
    Saving record DA2025/1536 - 64 Caraway Loop, Two Rocks, WA
    Saving record DA2025/1630 - 6 Southampton Lane, Mindarie, WA
    Saving record DA2025/1835 - 19 Jamaica Lane, Clarkson, WA
    Saving record DA2025/1435 - 35 Blackberry Drive, Ashby, WA
    Saving record DA2025/1861 - 4 Corinda Way, Ridgewood, WA
    Saving record DA2025/1670 - 23 Sierra Key, Mindarie, WA
      Pausing 0.837s
    Getting page: 1: https://yoursay.wanneroo.wa.gov.au/ccm/the_hive_projects/tools/the_hive_projects_list/load_more/2693?page=1
    /home/ianh/.local/share/mise/installs/ruby/3.2.2/lib/ruby/gems/3.2.0/gems/mechanize-2.8.5/lib/mechanize/pluggable_parsers.rb:107:in `new': MIME::Type.MIME::Type.new when called with a String is deprecated.
    Saving record DA2025/1549 - 71 Waddington Crescent, Koondoola, WA
      Pausing 0.837s
      Fetching detail page: https://yoursay.wanneroo.wa.gov.au/jindalee-dap-10-multiple-dwelling-19-bowsprit-view
      Extracted DA2025/1820 from page h1 heading
    Saving record DA2025/1820 - 19 Bowsprit View, Jindalee, WA
    Saving record DA2025/1635 - 7 Agonis Place, Wanneroo, WA
    Saving record DA2025/1821 - DAP - Commercial Development - 37 Amalfi Avenue Mindarie, WA
    Saving record DA2025/1524 - 22 McPharlin Avenue, Quinns Rocks, WA
      Pausing 1.154s
      Fetching detail page: https://yoursay.wanneroo.wa.gov.au/draft-local-planning-policy-28-licensed-premises
      Extracted 21033 from contact line instruction
    Saving record 21033 - Draft Local Planning Policy 2.8 - Licensed Premises, WA
      Pausing 1.371s
      Fetching detail page: https://yoursay.wanneroo.wa.gov.au/mindarie-amendment-no-234-district-planning-scheme-no-2
      Extracted 54343 from contact line instruction
    Saving record 54343 - Mindarie - Amendment No. 234 to District Planning Scheme no. 2, WA
    Deleting 0 applications scraped between  and 2025-12-28
      Running VACUUM to reclaim space...
    Finished! Added 16 records, and skipped 0 unprocessable records from 2 pages.

Execution time: ~ 15 seconds

## To run style and coding checks

    bundle exec rubocop

## To check for security updates

    gem install bundler-audit
    bundle-audit
