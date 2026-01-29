# frozen_string_literal: true

module Web
  module Parts
    # Presentation decorator for Race structs
    #
    # Wraps Structs::Race with view-specific presentation logic.
    # This keeps display concerns out of domain structs.
    #
    # Usage:
    #   race_part = parts_factory.wrap(race_struct)
    #   race_part.status_badge
    #   race_part.formatted_time
    #
    class Race < Base
      # Status badge with Tailwind CSS classes
      # @return [String] HTML-safe badge markup
      def status_badge
        badge_class = case value.status
        when "scheduled"
          "bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300"
        when "in_progress"
          "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300 animate-pulse"
        when "completed"
          "bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-300"
        when "cancelled"
          "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300"
        else
          "bg-gray-100 text-gray-800"
        end

        helpers.content_tag(:span, value.status.titleize, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{badge_class}")
      end

      # Race type badge
      # @return [String] HTML-safe badge markup
      def race_type_badge
        return "" unless value.race_type_name

        badge_class = "bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-300"
        helpers.content_tag(:span, value.race_type_name, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{badge_class}")
      end

      # Stage display with icon
      # @return [String] HTML-safe stage display
      def stage_display_with_icon
        icon = case value.stage_type
        when "Qualification"
          "🏁"
        when "Heat", "Quarterfinal"
          "🔥"
        when "Semifinal"
          "⚡"
        when "Final"
          "🏆"
        else
          "📍"
        end

        "#{icon} #{value.stage_name}"
      end

      # Formatted scheduled time with icon
      # @return [String] Formatted time or "Not scheduled"
      def formatted_scheduled_time_with_icon
        if value.scheduled_at.present?
          "🕐 #{value.formatted_scheduled_time}"
        else
          helpers.content_tag(:span, "Not scheduled", class: "text-gray-400 italic")
        end
      end

      # Formatted scheduled datetime for display
      # @return [String] Full datetime or "Not scheduled"
      def formatted_scheduled_datetime_display
        if value.scheduled_at.present?
          value.formatted_scheduled_datetime
        else
          helpers.content_tag(:span, "Not scheduled", class: "text-gray-400 italic")
        end
      end

      # Time until start (human readable)
      # @return [String] Human readable time until start
      def time_until_start
        return "Not scheduled" unless value.scheduled_at.present?
        return "Started" if value.started?

        minutes = value.minutes_until_start
        
        if minutes < 60
          "#{minutes} minutes"
        elsif minutes < 1440 # 24 hours
          hours = minutes / 60
          "#{hours} #{hours == 1 ? 'hour' : 'hours'}"
        else
          days = minutes / 1440
          "#{days} #{days == 1 ? 'day' : 'days'}"
        end
      end

      # Action buttons for race management
      # @return [String] HTML-safe action buttons
      def action_buttons(competition_id:)
        buttons = []

        # Show button
        buttons << helpers.link_to(
          "View",
          helpers.admin_competition_race_path(competition_id, value.id),
          class: "text-blue-600 hover:text-blue-900 dark:text-blue-400 dark:hover:text-blue-300"
        )

        # Edit button (only if not completed)
        if value.can_edit?
          buttons << helpers.link_to(
            "Edit",
            helpers.edit_admin_competition_race_path(competition_id, value.id),
            class: "text-indigo-600 hover:text-indigo-900 dark:text-indigo-400 dark:hover:text-indigo-300"
          )
        end

        # Delete button
        buttons << helpers.link_to(
          "Delete",
          helpers.admin_competition_race_path(competition_id, value.id),
          method: :delete,
          data: { 
            turbo_method: :delete,
            turbo_confirm: "Are you sure you want to delete '#{value.name}'?" 
          },
          class: "text-red-600 hover:text-red-900 dark:text-red-400 dark:hover:text-red-300"
        )

        helpers.safe_join(buttons, " | ")
      end

      # Link to race show page
      # @return [String] HTML-safe link
      def show_link(competition_id:)
        helpers.link_to(
          value.name,
          helpers.admin_competition_race_path(competition_id, value.id),
          class: "text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300 font-medium"
        )
      end

      # Status icon only
      # @return [String] Status icon
      def status_icon
        case value.status
        when "scheduled"
          "📅"
        when "in_progress"
          "▶️"
        when "completed"
          "✅"
        when "cancelled"
          "❌"
        else
          "❓"
        end
      end

      # Full display name with race type and stage
      # @return [String]
      def full_display_name
        "#{value.race_type_name || 'Race'} - #{value.stage_name}"
      end

      # DOM ID for Turbo Frame/Stream targeting
      # @return [String]
      def dom_id
        "race_#{value.id}"
      end

      # CSS classes for row based on status
      # @return [String]
      def row_classes
        base = "border-b dark:border-gray-700"
        
        case value.status
        when "in_progress"
          "#{base} bg-green-50 dark:bg-green-900/10"
        when "completed"
          "#{base} opacity-60"
        when "cancelled"
          "#{base} bg-red-50 dark:bg-red-900/10 opacity-60"
        else
          base
        end
      end

      # Position badge for ordering
      # @return [String] HTML-safe position badge
      def position_badge
        helpers.content_tag(
          :span,
          "##{value.position + 1}",
          class: "inline-flex items-center justify-center w-6 h-6 text-xs font-bold text-gray-600 bg-gray-200 rounded-full dark:bg-gray-700 dark:text-gray-300"
        )
      end

      # Scheduled date badge (just the date part)
      # @return [String]
      def scheduled_date_badge
        return "" unless value.scheduled_at.present?

        date_str = value.scheduled_at.strftime("%b %d")
        helpers.content_tag(
          :span,
          date_str,
          class: "text-sm text-gray-500 dark:text-gray-400"
        )
      end

      # Quick status indicator for tables
      # @return [String] HTML-safe colored dot
      def status_dot
        color = case value.status
        when "scheduled"
          "bg-blue-500"
        when "in_progress"
          "bg-green-500 animate-pulse"
        when "completed"
          "bg-gray-500"
        when "cancelled"
          "bg-red-500"
        else
          "bg-gray-400"
        end

        helpers.content_tag(
          :span,
          "",
          class: "inline-block w-2 h-2 rounded-full #{color}",
          title: value.status.titleize
        )
      end
    end
  end
end