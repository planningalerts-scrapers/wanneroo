#!/usr/bin/env ruby
# frozen_string_literal: true

require "scraperwiki"
require "mechanize"
require "json"

class Scraper
  INITIAL_PAGE_URL = "https://yoursay.wanneroo.wa.gov.au/planning-proposals"

  STATE = "WA"

  def clean_whitespace(text)
    text.gsub("\r", " ").gsub("\n", " ").squeeze(" ").strip
  end

  attr_accessor :pause_duration

  # Throttle block to be nice to servers we are scraping
  def throttle_block(extra_delay: 0.5)
    if @pause_duration
      puts "  Pausing #{@pause_duration}s"
      sleep(@pause_duration)
    end
    start_time = Time.now.to_f
    page = yield
    @pause_duration = (Time.now.to_f - start_time + extra_delay).round(3)
    page
  end

  # Cleanup and vacuum database of old records (planning alerts only looks at last 5 days)
  def cleanup_old_records
    cutoff_date = (Date.today - 30).to_s
    vacuum_cutoff_date = (Date.today - 35).to_s

    stats = ScraperWiki.sqliteexecute(
      "SELECT COUNT(*) as count, MIN(date_scraped) as oldest FROM data WHERE date_scraped < ?",
      [cutoff_date]
    ).first

    deleted_count = stats["count"]
    oldest_date = stats["oldest"]

    return unless deleted_count.positive? || ENV["VACUUM"]

    puts "Deleting #{deleted_count} applications scraped between #{oldest_date} and #{cutoff_date}"
    ScraperWiki.sqliteexecute("DELETE FROM data WHERE date_scraped < ?", [cutoff_date])

    # VACUUM roughly once each 33 days or if older than 35 days (first time) or if VACUUM is set
    return unless rand < 0.03 || (oldest_date && oldest_date < vacuum_cutoff_date) || ENV["VACUUM"]

    puts "  Running VACUUM to reclaim space..."
    ScraperWiki.sqliteexecute("VACUUM")
  end

  def extract_council_reference(project_name)
    # Match DA followed by year/number, with optional brackets
    match = project_name.match(%r{\(?(DA\d{4}/\d+)\)?})
    match ? match[1] : nil
  end

  def trim_project_name(project_name, suburb, council_reference)
    # Remove council reference, optionally enclosed in brackets and followed by hyphen
    text = project_name.gsub(/\(?#{Regexp.escape(council_reference)}\)?\s*-?\s*/, "")

    # Remove suburb prefix if present
    text = text.gsub(/^#{Regexp.escape(suburb)}\s*-?\s*/, "") if suburb.to_s != ""

    clean_whitespace(text)
  end

  def run
    agent = Mechanize.new
    agent.verify_mode = OpenSSL::SSL::VERIFY_NONE

    page = throttle_block do
      puts "Getting planning-proposals page"
      agent.get(INITIAL_PAGE_URL)
    end

    # Find the "Open Planning Proposals" section
    open_section = page.search("section.projects-list").find do |section|
      h3 = section.at("h3")
      h3&.text&.start_with?("Open")
    end

    raise "Could not find 'Open Planning Proposals' section" unless open_section

    process_json_pages(agent, open_section)
  end

  def extract_council_reference_from_details(agent, info_url)
    detail_page = throttle_block do
      puts "  Fetching detail page: #{info_url}"
      agent.get(info_url)
    end

    # Try to extract from h1 heading
    h1 = detail_page.at("h1.banner-content-heading")
    if h1
      ref = extract_council_reference(h1.text)
      if ref
        puts "  Extracted #{ref} from page h1 heading"
        return ref
      end
    end

    # Try to extract from contact details table
    contact_table = detail_page.at("table.contact-details")
    if contact_table
      contact_table.search("td").each do |td|
        text = td.text

        # Try standard DA format first
        ref = extract_council_reference(text)
        if ref
          puts "  Extracted #{ref} from contact line"
          return ref
        end

        # Try a simple number in brackets
        match = text.match(/\((\d+)\)/)
        ref = match[1] if match
        if ref
          puts "  Extracted #{ref} from within brackets contact line"
          return ref
        end

        # Try a simple number format after quote, ref, reference, number :
        match = text.match(/(?:quote|ref|reference|number):?\s+(\d+)/i)
        ref = match[1] if match
        if ref
          puts "  Extracted #{ref} from contact line instruction"
          return ref
        end
      end
    end

    puts "Unable to extract reference from: #{info_url}"
    nil
  rescue StandardError => e
    puts "Error fetching detail page #{info_url}: #{e.message}"
    nil
  end

  def process_json_pages(agent, open_section)
    data_route = open_section["data-route"]
    current_page = 0

    unless data_route
      puts "Error: unable to find data route"
      exit 1
    end

    added = found = 0

    loop do
      url = "#{data_route}?page=#{current_page}"
      response = throttle_block do
        puts "Getting page: #{current_page}: #{url}"
        response = agent.get(url)
      end
      current_page += 1

      data = JSON.parse(response.body)

      result = data["result"]
      more_to_load = data["moreToLoad"]

      result.each do |data|
        found += 1
        project_name = data["projectName"]
        description = data["projectDescription"]
        info_url = data["projectPath"]
        suburb = data["projectLocation"]
        council_reference = extract_council_reference(project_name) ||
                            extract_council_reference(description) ||
                            extract_council_reference_from_details(agent, info_url)

        # fix near empty descriptions
        description = project_name if [council_reference, suburb].include? description

        unless project_name
          puts "Warning: No project name found! (skipped)"
          next
        end
        unless description
          puts "Warning: No description found! (skipped)"
          next
        end
        unless council_reference
          puts "Warning - Unable to extract council reference for #{project_name}"
          next
        end

        trimmed_project_name = trim_project_name(project_name, suburb, council_reference)

        # Build address - extract from the trimmed_project_name if it contains " – "
        address_parts = []
        if trimmed_project_name.include?(" – ")
          parts = trimmed_project_name.split(" – ")
          address_parts << parts.last if parts.length > 1
        else
          # Fallback: use trimmed_project_name as is
          address_parts << trimmed_project_name
        end
        address_parts << suburb if suburb.to_s != "" && !address_parts.last.to_s.end_with?(suburb)
        address_parts << STATE unless address_parts.last == STATE
        address = address_parts.join(", ")

        record = {
          "council_reference" => council_reference,
          "address" => address,
          "description" => project_name,
          "info_url" => info_url,
          "date_scraped" => Date.today.to_s,
        }
        added += 1
        puts "Saving record #{council_reference} - #{address}"
        ScraperWiki.save_sqlite(["council_reference"], record)
      end
      break unless more_to_load && current_page < 100
    end
    cleanup_old_records
    puts "Finished! Added #{added} records, and skipped #{found - added} unprocessable records from #{current_page} pages."
  end
end

Scraper.new.run if __FILE__ == $PROGRAM_NAME
