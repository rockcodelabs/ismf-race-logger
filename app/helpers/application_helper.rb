# frozen_string_literal: true

module ApplicationHelper
  # Returns Tailwind CSS classes for color badge based on color code
  # Used in location template and race location views
  #
  # @param color [String] Color code: 'green', 'red', 'yellow', or nil
  # @return [String] Tailwind CSS classes
  def color_badge_class(color)
    case color
    when 'green'
      'bg-green-100 text-green-800'
    when 'red'
      'bg-red-100 text-red-800'
    when 'yellow'
      'bg-yellow-100 text-yellow-800'
    else
      'bg-gray-100 text-gray-800'
    end
  end

  # Returns a country flag emoji for an ISO 3166-1 alpha-3 country code
  # Converts to alpha-2 then builds regional indicator symbol pair
  #
  # @param alpha3 [String, nil] e.g. "ITA", "CHE", "DEU"
  # @return [String] e.g. "🇮🇹", "🇨🇭", "🇩🇪"
  def country_flag_emoji(alpha3)
    return "" if alpha3.blank?

    iso3_to_2 = {
      "AND" => "AD", "ARG" => "AR", "AUS" => "AU", "AUT" => "AT",
      "AZE" => "AZ", "BEL" => "BE", "BGR" => "BG", "BIH" => "BA",
      "CAN" => "CA", "CHE" => "CH", "CHN" => "CN", "HRV" => "HR",
      "CZE" => "CZ", "DEU" => "DE", "ESP" => "ES", "FIN" => "FI",
      "FRA" => "FR", "GBR" => "GB", "GRC" => "GR", "HUN" => "HU",
      "IND" => "IN", "IRN" => "IR", "ISR" => "IL", "ITA" => "IT",
      "JPN" => "JP", "KAZ" => "KZ", "KOR" => "KR", "LIE" => "LI",
      "LTU" => "LT", "MDA" => "MD", "MKD" => "MK", "NLD" => "NL",
      "NOR" => "NO", "NZL" => "NZ", "POL" => "PL", "PRT" => "PT",
      "ROU" => "RO", "RUS" => "RU", "ZAF" => "ZA", "SRB" => "RS",
      "SVN" => "SI", "SVK" => "SK", "SWE" => "SE", "TUR" => "TR",
      "UKR" => "UA", "USA" => "US"
    }.freeze

    alpha2 = iso3_to_2[alpha3.upcase] || alpha3.upcase[0..1]
    alpha2.chars.map { |c| (0x1F1E6 + (c.ord - "A".ord)).chr(Encoding::UTF_8) }.join
  end
end
